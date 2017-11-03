# $Id: 98_todoist.pm 0016 Version 0.4.2 2017-11-03 14:06:10Z marvin1978 $

package main;

use strict;
use warnings;
use Data::Dumper; 
use JSON;
use MIME::Base64;
use Encode;
use Date::Parse;
use Data::UUID;



sub todoist_Initialize($) {
    my ($hash) = @_;

    $hash->{SetFn}    = "todoist_Set";
		$hash->{DefFn}    = "todoist_Define";
		$hash->{UndefFn}  = "todoist_Undefine";
		$hash->{AttrFn}   = "todoist_Attr";
		$hash->{RenameFn} = "todoist_Rename";   
		$hash->{CopyFn}	  = "todoist_Copy";
		$hash->{DeleteFn} = "todoist_Delete";
		$hash->{NotifyFn} = "todoist_Notify";
	
    $hash->{AttrList} = "disable:1,0 ".
												"pollInterval ".
												"do_not_notify ".
												"sortTasks:1,0 ".
												"getCompleted:1,0 ".
												"showPriority:1,0 ".
												"autoGetUsers:1,0 ".
												$readingFnAttributes;
	
	return undef;
}

sub todoist_Define($$) {
  my ($hash, $def) = @_;
	my $now = time();
	my $name = $hash->{NAME}; 
  
	
	my @a = split( "[ \t][ \t]*", $def );
	
	if ( int(@a) < 2 ) {
    my $msg = "Wrong syntax: define <name> todoist <Project id>";
    Log3 $name, 4, $msg;
    return $msg;
  }
	

	## set internal variables
	$hash->{PID}=$a[2];
	$hash->{INTERVAL}=AttrVal($name,"pollInterval",undef)?AttrVal($name,"pollInterval",undef):1800;
	
	## check if Access Token is needed
	my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
	my ($err, $password) = getKeyValue($index);
	
	$hash->{helper}{PWD_NEEDED}=1 if ($err || !$password);
		
	$hash->{NOTIFYDEV}= "global";
	
	## start polling
	if ($init_done) {
		## at first, we delete old readings. List could have changed
		CommandDeleteReading(undef, "$hash->{NAME} (T|t)ask_.*");
		CommandDeleteReading(undef, "$hash->{NAME} listText");
		## set status 
		readingsSingleUpdate($hash,"state","active",1) if (!$hash->{helper}{PWD_NEEDED} && !IsDisabled($name) );
		readingsSingleUpdate($hash,"state","inactive",1) if ($hash->{helper}{PWD_NEEDED});
		## remove timers
		RemoveInternalTimer($hash,"todoist_GetTasks");
		todoist_GetTasks($hash) if (!IsDisabled($name) && !$hash->{helper}{PWD_NEEDED});
	}
	
	return undef;
}

sub todoist_GetPwd($) {
	my ($hash) = @_;
	
	my $name=$hash->{NAME};
	
	my $pwd="";
	
	my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
	my $key = getUniqueId().$index;
	
	my ($err, $password) = getKeyValue($index);
				
	if ($err) {
		$hash->{helper}{PWD_NEEDED} = 1;
		Log3 $name, 4, "todoist ($name): unable to read password from file: $err";
		return undef;
	}	  
	
	if ($password) {
		$pwd=decode_base64($password);
	}
	
	return undef if ($pwd eq "");
	
	return $pwd;
}

## set error Readings
sub todoist_ErrorReadings($;$) {
	my ($hash,$errorText) = @_;
	
	$errorText="no data" if (!defined($errorText));
	
	if (defined($hash->{helper}{errorData}) && $hash->{helper}{errorData} ne "") {
		$errorText=$hash->{helper}{errorData};
	}
	
	my $name = $hash->{NAME};

	readingsBeginUpdate( $hash );
	readingsBulkUpdate( $hash,"error",$errorText );
	readingsBulkUpdate( $hash,"lastError",$errorText );
	readingsEndUpdate( $hash, 1 );
	
	Log3 $name,3, "todoist ($name): ".$errorText;
	
	$hash->{helper}{errorData}="";
	return undef;
}


# update Task
sub todoist_UpdateTask($$$) {
	my ($hash,$cmd, $type) = @_;
	
	my($a, $h) = parseParams($cmd);
	
	my $name=$hash->{NAME};
	
	Log3 $name,5, "$name: Type: ".Dumper($type);
	
	my $param;
	
	my $pwd="";
	
	my %commands=();
	
	my $method;
	my $taskId;
	my $title;
	
	## get Task-ID
	my $tid = @$a[0];
	
	## check if ID is todoist ID
	my @temp=split(":",$tid);
	
	
	## use the todoist ID
	if (@temp && $temp[0] eq "ID") {
		$taskId = int($temp[1]);
		$title = $hash->{helper}{"TITLE"}{$temp[1]};
	}
	## use Task-Number 
	else {
		$tid=int($tid);
		$taskId=$hash->{helper}{"IDS"}{"Task_".$tid};
		$title=ReadingsVal($name,"Task_".sprintf('%03d',$tid),"-");
	}
	
	my $uuidO=Data::UUID->new;
	my $uuid=$uuidO->create_str();
	
	my $commandsStart="[{";
			
	my $commandsEnd="}]";
	
	my $tType;
	my %args=();
	

	## if no token is needed and device is not disabled, check token and get list vom todoist
	if (!$hash->{helper}{PWD_NEEDED} && !IsDisabled($name)) {
		
		## get password
		$pwd=todoist_GetPwd($hash);
		
		if ($pwd) {
			Log3 $name,4, "$name: hash: ".Dumper($hash);
			
			## complete a task
			if ($type eq "complete") {

				# variables for the commands parameter
				$tType = "item_complete";
				%args = (
					ids => '['.$taskId.']',
				);
				Log3 $name,5, "$name: Args: ".Dumper(%args);
				$method="POST";
			}
			## uncomplete a task
			elsif ($type eq "uncomplete") {

				# variables for the commands parameter
				$tType = "item_uncomplete";
				%args = (
					ids => '['.$taskId.']',
				);
				Log3 $name,5, "$name: Args: ".Dumper(%args);
				$method="POST";
			}
			## update a task 
			elsif ($type eq "update") {
				$tType = "item_update";
				%args = (
					id => $taskId,
				);
				
				## change title
				$args{'content'} = $h->{"title"} if($h->{'title'});
				## change dueDate
				$args{'date_string'} = $h->{"dueDate"} if($h->{'dueDate'});
				## change dueDate (if someone uses due_date in stead of dueDate)
				$args{'date_string'} = $h->{"due_date"} if ($h->{'due_date'});
				## change priority
				$args{'priority'} = int($h->{"priority"}) if ($h->{"priority"});
					
				## Debug
				#Log3 $name, 1, "todoist ($name): Debug: ".Dumper(%datas);
				
				$method="POST";
			}
			## delete a task
			elsif ($type eq "delete") {
				$tType = "item_delete";
				%args = (
					ids => '['.$taskId.']',
				);
				$method="POST";
			}
			else {
				return undef;
			}
			
			Log3 $name,5, "todoist ($name): Data Array sent to todoist API: ".Dumper(%args);
			
			my $dataArr=$commandsStart.'"type":"'.$tType.'","temp_id":"'.$taskId.'","uuid":"'.$uuid.'","args":'.encode_json(\%args).$commandsEnd;
			
			Log3 $name,4, "todoist ($name): Data Array sent to todoist API: ".$dataArr;
		
			my $data= {
				token			=>		$pwd,
				commands	=>		$dataArr
			};
			
			Log3 $name,4, "todoist ($name): JSON sent to todoist API: ".Dumper($data);
			
			$param = {
				url        => "https://todoist.com/api/v7/sync",
				data			 => $data,
				tTitle		 => $title,
				method		 => $method,
				wType			 => $type,
				taskId		 => $taskId,
				timeout    => 7,
				header 		 => "Content-Type: application/x-www-form-urlencoded",
				hash 			 => $hash,
				callback   => \&todoist_HandleTaskCallback,  ## call callback sub to work with the data we get
			};
			
			Log3 $name,5, "todoist ($name): Param: ".Dumper($param);
			
			## non-blocking access to todoist API
			InternalTimer(gettimeofday()+1, "HttpUtils_NonblockingGet", $param, 0);
		}
		else {
			todoist_ErrorReadings($hash,"access token empty");
		}
	}
	else {
		if (!IsDisabled($name)) {
			todoist_ErrorReadings($hash,"no access token set");
		}
		else {
			todoist_ErrorReadings($hash,"device is disabled");
		}
	
	}
	
	return undef;
}

# create Task
sub todoist_CreateTask($$) {
	my ($hash,$cmd) = @_;
	
	my($a, $h) = parseParams($cmd);
	
	my $name=$hash->{NAME};
	
	my $param;
	
	my $pwd="";
	
	my $assigne_id="";
	
	## we try to send a due_date (in developement)
	my @tmp = split( ":", join(" ",@$a) );
	
	my $title=$tmp[0];
	
	
	## if no token is needed and device is not disabled, check token and get list vom todoist
	if (!$hash->{helper}{PWD_NEEDED} && !IsDisabled($name)) {
		
		## get password
		$pwd=todoist_GetPwd($hash);
		
		if ($pwd) {
		
			Log3 $name,5, "$name: hash: ".Dumper($hash);
			
			# data array for API - we could transfer more data
			
			my $data = {
									 project_id	        	=> int($hash->{PID}),
									 content 	        		=> encode_utf8($title),
									 token								=> $pwd,
			};
			
			## check for dueDate as Parameter or part of title - push to hash
			if (!$tmp[1] && $h->{"dueDate"}) { ## parameter
				$data->{'date_string'} = $h->{"dueDate"};
			}
			elsif ($tmp[1]) { ## title
				$data->{'date_string'} = $tmp[1];
			}
			else {
			
			}
			
			## if someone uses due_date - no problem
			$data->{'date_string'} = $h->{"due_date"} if ($h->{"due_date"});
			
			
			## Task is starred? Push it to hash
			$data->{'priority'} = $h->{"priority"} if ($h->{"priority"});
			
			
			
			Log3 $name,4, "todoist ($name): Data Array sent to todoist API: ".Dumper($data);
		
			
			$param = {
				url        => "https://todoist.com/api/v7/items/add",
				data			 => $data,
				tTitle		 => encode_utf8($title),
				method		 => "POST",
				wType			 => "create",
				timeout    => 7,
				header		 => "Content-Type: application/x-www-form-urlencoded",
				hash 			 => $hash,
				callback   => \&todoist_HandleTaskCallback,  ## call callback sub to work with the data we get
			};
			
			Log3 $name,5, "todoist ($name): Param: ".Dumper($param);
			
			## non-blocking access to todoist API
			InternalTimer(gettimeofday()+1, "HttpUtils_NonblockingGet", $param, 0);
		}
		else {
			todoist_ErrorReadings($hash,"access token empty");
		}
	}
	else {
		if (!IsDisabled($name)) {
			todoist_ErrorReadings($hash,"no access token set");
		}
		else {
			todoist_ErrorReadings($hash,"device is disabled");
		}
	}
	
	
	return undef;
}

sub todoist_HandleTaskCallback($$$){
	my ($param, $err, $data) = @_;
	
	my $hash = $param->{hash};
	my $title = $param->{tTitle};
	
	my $taskId = $param->{taskId};
	
	my $reading = $title;
	
	my $name = $hash->{NAME}; 
	
	Log3 $name,4, "todoist ($name):  ".$param->{wType}."Task Callback data: ".Dumper($data);

	my $error;
	
	## errors? Log and readings
	if ($err ne "") {
		todoist_ErrorReadings($hash,$err);
	}
	else {
	
		## if "sync_status" in $data, we were successfull
		if((($data =~ /sync_status/ && $data=~/ok/) || $data =~ /sync_id/) && eval {decode_json($data)}) {
			
			readingsBeginUpdate($hash);
		
			if ($data ne "") {
				my $decoded_json = decode_json($data);
				
				$reading .= " - ".$taskId if (!$decoded_json->{id});
				$reading .= " - ".$decoded_json->{id} if ($decoded_json->{id});
				
				## do some logging
				Log3 $name,4, "todoist ($name):  Task Callback data (decoded JSON): ".Dumper($decoded_json );
				
				Log3 $name,4, "todoist ($name): Callback-ID: $taskId";
			}
			Log3 $name,4, "todoist ($name):  Task Callback error(s): ".Dumper($err);
			Log3 $name,5, "todoist ($name):  Task Callback param: ".Dumper($param);
			
			readingsBulkUpdate($hash, "error","none");
			readingsBulkUpdate($hash, "lastCreatedTask",$reading) if ($param->{wType} eq "create");
			readingsBulkUpdate($hash, "lastCompletedTask",$reading) if ($param->{wType} eq "complete");
			readingsBulkUpdate($hash, "lastUncompletedTask",$reading) if ($param->{wType} eq "uncomplete");
			readingsBulkUpdate($hash, "lastUpdatedTask",$reading) if ($param->{wType} eq "update");
			readingsBulkUpdate($hash, "lastDeletedTask",$reading) if ($param->{wType} eq "delete");
			
			## some Logging
			Log3 $name, 4, "todoist ($name): successfully created new task $title" if ($param->{wType} eq "create");
			Log3 $name, 4, "todoist ($name): successfully ".$param->{wType}."ed task $title";
			
			readingsEndUpdate( $hash, 1 );
		}
		## we got an error from the API
		else {
			my $error="malformed JSON";
			
			# if the error is in the file, log this error
			if (eval {decode_json($data)}) {
				my $decoded_json = decode_json($data);
				$error = $decoded_json->{error} if ($decoded_json->{error});
			}
			$error = $param->{wType}."Task: ";
			$error .= $error;
			$error .= "Unknown";
			Log3 $name, 3, "todoist ($name): got error: ".$error;
			todoist_ErrorReadings($hash,$error);
		}
		
	}	
	
	RemoveInternalTimer($hash,"todoist_GetTasks");
	InternalTimer(gettimeofday()+1, "todoist_GetTasks", $hash, 0); ## loop with Interval
	
	return undef;
}



## get all Tasks
sub todoist_GetTasks($;$) {
	my ($hash,$completed) = @_;
	
	my $name=$hash->{NAME};
	
	$completed = 0 unless defined($completed);
	
	my $param;
	my $param2;
	
	my $pwd="";
	
	## if no token is needed and device is not disabled, check token and get list vom todoist
	if (!$hash->{helper}{PWD_NEEDED} && !IsDisabled($name)) {
		
		## get password
		$pwd=todoist_GetPwd($hash);
		
		if ($pwd) {
		
			Log3 $name,5, "$name: hash: ".Dumper($hash);
			
			## check if we get also the completed Tasks
			my $url = "https://todoist.com/api/v7/projects/get_data";
			
			if ($completed == 1) {
				$url = "https://todoist.com/api/v7/completed/get_all";
			}
			
			my $data= {
				token						=> $pwd,
				project_id			=> $hash->{PID}
			};
			
			Log3 $name,4, "todoist ($name): Curl Data: ".Dumper($data);
			
			## get the tasks
			$param = {
				url        => $url,
				method		 => "POST",
				data			 => $data,
				header		 => "Content-Type: application/x-www-form-urlencoded",
				timeout    => 7,
				completed  => $completed,
				hash 			 => $hash,
				callback   => \&todoist_GetTasksCallback,  ## call callback sub to work with the data we get
			};

			
			
			Log3 $name,4, "todoist ($name): Param: ".Dumper($param);
			
			## non-blocking access to todoist API
			InternalTimer(gettimeofday()+0.2, "HttpUtils_NonblockingGet", $param, 0);
			
			
		}
		else {
			todoist_ErrorReadings($hash,"access token empty");
		}
	}
	else {
		if (!IsDisabled($name)) {
			todoist_ErrorReadings($hash,"no access token set");
		}
		else {
			todoist_ErrorReadings($hash,"device is disabled");
		}
	}
	
	## one more time, if completed
	if (AttrVal($name,"getCompleted",0)==1 && $completed != 1) {		
		InternalTimer(gettimeofday()+0.5, "todoist_doGetCompTasks", $hash, 0);
	}
	InternalTimer(gettimeofday()+2, "todoist_GetUsers", $hash, 0) if ($completed != 1 && AttrVal($name,"autoGetUsers",1) == 1);
	
	return undef;
}

sub todoist_doGetCompTasks($) {
	my ($hash) = @_;
	todoist_GetTasks($hash,1);
}

## Callback for the lists tasks
sub todoist_GetTasksCallback($$$){
	my ($param, $err, $data) = @_;
	
	my $hash=$param->{hash};
	
	my $name = $hash->{NAME}; 
	
	Log3 $name,4, "todoist ($name):  Task Callback data-raw: ".Dumper($data);
	
	my $lText="";
	
	Log3 $name,5, "todoist ($name):  Task Callback param: ".Dumper($param);
	
	readingsBeginUpdate($hash);
	
	if ($err ne "") {
		todoist_ErrorReadings($hash,$err);
	}
	else {
		my $decoded_json="";
		
		if (eval{decode_json($data)}) {
		
			$decoded_json = decode_json($data);
			
			Log3 $name,5, "todoist ($name):  Task Callback data (decoded JSON): ".Dumper($decoded_json );
		}
		
		if ((ref($decoded_json) eq "HASH" && !$decoded_json->{items}) || $decoded_json eq "") {
			$hash->{helper}{errorData} = Dumper($data);
			InternalTimer(gettimeofday()+0.2, "todoist_ErrorReadings",$hash, 0); 
		}
		else {
			my @taskseries = @{$decoded_json->{items}};
			## do some logging
			Log3 $name,5, "todoist ($name):  Task Callback data (taskseries): ".Dumper(@taskseries );
			
			my $i=0;
			
			## count the results
			my $count=@taskseries;
			
			## delete Task_* readings for changed list
			if ($param->{completed} != 1 || (ReadingsVal($name,"count",0)==0 && $count == 0)) {
				CommandDeleteReading(undef, "$hash->{NAME} (T|t)ask_.*");
				delete($hash->{helper});
			}

			
			
			## no data
			if ($count==0 && $param->{completed} != 1) {
				InternalTimer(gettimeofday()+0.2, "todoist_ErrorReadings",$hash, 0); 
				readingsBulkUpdate($hash, "count",0);
			}
			else {
				$i = ReadingsVal($name,"count",0) if ($param->{completed} == 1);
				foreach my $task (@taskseries) {
					my $title = encode_utf8($task->{content});
					$title =~ s/^\s+|\s+$//g;
					
					my $t = sprintf ('%03d',$i);
					
					## get todoist-Task-ID
					my $taskID = $task->{id};
					
					readingsBulkUpdate($hash, "Task_".$t,$title);
					readingsBulkUpdate($hash, "Task_".$t."_ID",$taskID);

					## a few helper for ID and revision
					$hash->{helper}{"IDS"}{"Task_".$i}=$taskID;
					$hash->{helper}{"TITLE"}{$taskID}=$title;
					$hash->{helper}{"WID"}{$taskID}=$i;
					
					## set completed_date if present
					if (defined($task->{completed_date})) {
						## if there is a completed task, we create a new reading
						readingsBulkUpdate($hash, "Task_".$t."_completedAt",FmtDateTime(str2time($task->{completed_date})));
						$hash->{helper}{"COMPLETED_AT"}{$taskID}=FmtDateTime(str2time($task->{completed_date}));
						readingsBulkUpdate($hash, "Task_".$t."_completedById",$task->{user_id});
						$hash->{helper}{"COMPLETED_BY_ID"}{$taskID}=$task->{user_id};
					}
					
					## set due_date if present
					if (defined($task->{due_date_utc}) && $task->{due_date_utc} ne 'null') {
						## if there is a task with due date, we create a new reading
						readingsBulkUpdate($hash, "Task_".$t."_dueDate",FmtDateTime(str2time($task->{due_date_utc})));
						$hash->{helper}{"DUE_DATE"}{$taskID}=FmtDateTime(str2time($task->{due_date_utc}));
					}
					
					## set responsible_uid if present
					if (defined($task->{responsible_uid})) {
						## if there is a task with responsible_uid, we create a new reading
						readingsBulkUpdate($hash, "Task_".$t."_responsibleUid",$task->{responsible_uid});
						$hash->{helper}{"RESPONSIBLE_UID"}{$taskID}=$task->{responsible_uid};
					}
					
					## set assigned_by_uid if present
					if (defined($task->{assigned_by_uid})) {
						## if there is a task with assigned_by_uid, we create a new reading
						readingsBulkUpdate($hash, "Task_".$t."_assignedByUid",$task->{assigned_by_uid});
						$hash->{helper}{"ASSIGNEDBY_UID"}{$taskID}=$task->{assigned_by_uid};
					}
					
					## set priority if present
					if (defined($task->{priority})) {
						readingsBulkUpdate($hash, "Task_".$t."_priority",$task->{priority}) if (AttrVal($name,"showPriority",0)==1);
						$hash->{helper}{"PRIORITY"}{$taskID}=$task->{priority};
					}
					
					## set recurrence_type and count if present
					if (defined($task->{date_string})) {
						## if there is a task with recurrence_type, we create new readings
						readingsBulkUpdate($hash, "Task_".$t."_recurrenceType",$task->{date_string});
						$hash->{helper}{"RECURRENCE_TYPE"}{$taskID}=$task->{date_string};
					}
					
					if ($param->{completed} != 1) {
						$lText.=", " if ($i != 0);
						$lText.=$title;
					}
					$i++;
				}
				readingsBulkUpdate($hash, "error","none");
				readingsBulkUpdate($hash, "count",$i);
				
				
			}
		}
	}

	## list Text for TTS, Text-Message...
	if ($param->{completed} != 1) {
		$lText="-" if ($lText eq "");
		readingsBulkUpdate($hash,"listText",$lText) if ($lText ne "");
	}
	
	
	readingsEndUpdate( $hash, 1 );
	
	## sort Tasks alphabetically if set
	todoist_sort($hash) if (AttrVal($name,"sortTasks",0) == 1);
	
	
	RemoveInternalTimer($hash,"todoist_GetTasks");
	InternalTimer(gettimeofday()+$hash->{INTERVAL}, "todoist_GetTasks", $hash, 0); ## loop with Interval
	
	return undef;
}


## get all Users
sub todoist_GetUsers($) {
	my ($hash) = @_;
	
	my $name=$hash->{NAME};
	
	my $param;
	
	my $pwd="";
	
	## if no token is needed and device is not disabled, check token and get list vom todoist
	if (!$hash->{helper}{PWD_NEEDED} && !IsDisabled($name)) {
		
		## get password
		$pwd=todoist_GetPwd($hash);
		
		my $data= {
			token						=> $pwd,
			sync_token			=> '*',
			resource_types	=> '["collaborators"]'
		};
		
		if ($pwd) {
		
			Log3 $name,5, "$name: hash: ".Dumper($hash);
			
			$param = {
				url        => "https://todoist.com/api/v7/sync",
				data			 => $data,
				timeout    => 7,
				method		 => "POST",
				header		 => "Content-Type: application/x-www-form-urlencoded",
				hash 			 => $hash,
				callback   => \&todoist_GetUsersCallback,  ## call callback sub to work with the data we get
			};
			
			
			Log3 $name,5, "todoist ($name): Param: ".Dumper($param);
			
			## non-blocking access to todoist API
			InternalTimer(gettimeofday()+1, "HttpUtils_NonblockingGet", $param, 0);
		}
		else {
			todoist_ErrorReadings($hash,"access token empty");
		}
	}
	else {
		if (!IsDisabled($name)) {
			todoist_ErrorReadings($hash,"no access token set");
		}
		else {
			todoist_ErrorReadings($hash,"device is disabled");
		}
	}
	
	return undef;
}

sub todoist_GetUsersCallback($$$){
	my ($param, $err, $data) = @_;
	
	my $hash=$param->{hash};
	
	my $name = $hash->{NAME}; 
	
	Log3 $name,5, "todoist ($name): User Callback data: ".Dumper($data);
	
	if ($err ne "") {
		todoist_ErrorReadings($hash,$err);
	}
	else {
		my $decoded_json="";
		
		if (eval{decode_json($data)}) {
		
			$decoded_json = decode_json($data);
			
			Log3 $name,5, "todoist ($name):  User Callback data (decoded JSON): ".Dumper($decoded_json );
		}
		
		readingsBeginUpdate($hash);
		if ((ref($decoded_json) eq "HASH" && !$decoded_json->{collaborators}) || $decoded_json eq "") {
			$hash->{helper}{errorData} = Dumper($data);
			InternalTimer(gettimeofday()+0.2, "todoist_ErrorReadings",$hash, 0); 
		}
		else {
			my @users = @{$decoded_json->{collaborators}};
			my @states = @{$decoded_json->{collaborator_states}};
			## count the results
			my $count=@users;
			
			## delete Task_* readings for changed list
			CommandDeleteReading(undef, "$hash->{NAME} (U|u)ser_.*");
			delete($hash->{helper}{USER});
			
			Log3 $name,5, "todoist ($name):  Task States: ".Dumper(@states);
			
			## no data
			if ($count==0) {
				readingsBulkUpdate($hash, "error","no data");
				readingsBulkUpdate($hash, "lastError","no data");
				readingsBulkUpdate($hash, "countUsers",0);
			}
			else {
			
				my $i=0;
				foreach my $user (@users) {
					my $do=0;
					foreach my $state (@states) {
						$do=1 if ($user->{id} == $state->{user_id} && $state->{project_id} == $hash->{PID});
					}
					
					if ($do==1) {
						my $userName = encode_utf8($user->{full_name});
						my $t = sprintf ('%03d',$i);
						
						## get todoist-User-ID
						my $userID = $user->{id};
						
						readingsBulkUpdate($hash, "User_".$t,$userName);
						readingsBulkUpdate($hash, "User_".$t."_ID",$userID);

						## a few helper for ID and revision
						$hash->{helper}{USER}{"IDS"}{"User_".$i}=$userID;
						$hash->{helper}{USER}{"NAME"}{$userID}=$userName;
						$hash->{helper}{USER}{"WID"}{$userID}=$i;
						$i++;
					}
				}
				readingsBulkUpdate($hash, "error","none");
				readingsBulkUpdate($hash, "countUsers",$i);
			}
		}
		readingsEndUpdate( $hash, 1 );
	}
		
	
}

## sort alphabetically
sub todoist_sort($) {
	my ($hash) = @_;
	
	my $name=$hash->{NAME};
	
	my $lText="";
	
	my %list;
	
	
	## get all Readings
	my $readings = $hash->{READINGS};
	## prepare Hash for sorting
	foreach my $key (keys %{$readings}) {
		if ($key =~ m/^Task_\d\d\d$/) {
			my @temp = split("_",$key);
			my $tid = int($temp[1]);
			my $val = $readings->{$key}{VAL};
			my $id = ReadingsVal($name,$key."_ID",0);
			$list{$tid} = {content => $val, ID => $id};
		}
	}
	
	CommandDeleteReading(undef, "$hash->{NAME} (T|t)ask_.*");
	
	readingsBeginUpdate($hash);
	
	delete($hash->{helper}{"IDS"});
	
	## sort Tasks and write them back
	my $i = 0;
	foreach my $key (sort {lc($list{$a}->{content}) cmp lc($list{$b}->{content})} keys(%list)) {
		my $data = $list{$key};
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i),$data->{content});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_dueDate",$hash->{helper}{"DUE_DATE"}{$data->{ID}}) if ($hash->{helper}{"DUE_DATE"}{$data->{ID}});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_responsibleUid",$hash->{helper}{"RESPONSIBLE_UID"}{$data->{ID}}) if ($hash->{helper}{"RESPONSIBLE_UID"}{$data->{ID}});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_assignedByUid",$hash->{helper}{"ASSIGNEDBY_UID"}{$data->{ID}}) if ($hash->{helper}{"ASSIGNEDBY_UID"}{$data->{ID}});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_priority",$hash->{helper}{"PRIORITY"}{$data->{ID}}) if ($hash->{helper}{"PRIORITY"}{$data->{ID}} && AttrVal($name,"showPriority",0)==1);
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_recurrenceType",$hash->{helper}{"RECURRENCE_TYPE"}{$data->{ID}}) if ($hash->{helper}{"RECURRENCE_TYPE"}{$data->{ID}});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_completedAt",$hash->{helper}{"COMPLETED_AT"}{$data->{ID}}) if ($hash->{helper}{"COMPLETED_AT"}{$data->{ID}});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_completedById",$hash->{helper}{"COMPLETED_BY_ID"}{$data->{ID}}) if ($hash->{helper}{"COMPLETED_BY_ID"}{$data->{ID}});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_ID",$data->{ID});
		
		$hash->{helper}{"IDS"}{"Task_".$i} = $data->{ID};
		$hash->{helper}{"WID"}{$data->{ID}} = $i;
		
		if (!$hash->{helper}{"COMPLETED_AT"}{$data->{ID}}) {
			$lText.=", " if ($i != 0);
			$lText.=$data->{content};
		}
		$i++;
	}
	
	## list Text for TTS, Text-Message...
	$lText="-" if ($lText eq "");
	readingsBulkUpdate($hash,"listText",$lText) if ($lText ne "");
	
	readingsEndUpdate( $hash, 1 );
	return undef;
}


#################################################
# delete all Tasks from list
sub todoist_clearList($) {
	my ($hash) = @_;
	
	## iterate through all tasks
	foreach my $id (%{$hash->{helper}{IDS}}) {
		my $dHash->{hash}=$hash;
		if ($id !~ /Task_/) {
			$dHash->{id}=$id;
			InternalTimer(gettimeofday()+0.4, "todoist_doUpdateTask", $dHash, 0);
		}
	}
}

sub todoist_doUpdateTask($) {
	my ($dHash) = @_;
	my $hash = $dHash->{hash};
	my $id = $dHash->{id};
	my $name = $hash->{NAME};
	todoist_UpdateTask($hash,"ID:".$id,"delete");
}


sub todoist_Undefine($$) {
  my ($hash, $arg) = @_;
	
  RemoveInternalTimer($hash);
	
  return undef;
}

################################################
# If Device is deleted, delete the password data
sub todoist_Delete($$) {
    my ($hash, $name) = @_;  
    
    my $old_index = "todoist_".$name."_passwd";
    
    my $old_key =getUniqueId().$old_index;
    
    my ($err, $old_pwd) = getKeyValue($old_index);
    
    return undef unless(defined($old_pwd));
		    
    setKeyValue($old_index, undef);

		
		Log3 $name, 3, "todoist: device $name as been deleted. Access-Token has been deleted too.";
}

################################################
# If Device is renamed, copy the password data
sub todoist_Rename($$) {
    my ($new, $old) = @_;  
    
    my $old_index = "todoist_".$old."_passwd";
    my $new_index = "todoist_".$new."_passwd";
    
    my $old_key =getUniqueId().$old_index;
    my $new_key =getUniqueId().$new_index;
    
    my ($err, $old_pwd) = getKeyValue($old_index);
    
    return undef unless(defined($old_pwd));
    
    setKeyValue($new_index, $old_pwd);
    setKeyValue($old_index, undef);
		
		Log3 $new, 3, "todoist: device has been renamed from $old to $new. Access-Token has been assigned to new name.";
}

################################################
# If Device is copied, copy the password data
sub todoist_Copy($$)
{
    my ($old, $new) = @_;  
    
    my $old_index = "todoist_".$old."_passwd";
    my $new_index = "todoist_".$new."_passwd";
    
    my $old_key =getUniqueId().$old_index;
    my $new_key =getUniqueId().$new_index;
    
    my ($err, $old_pwd) = getKeyValue($old_index);
    
    return undef unless(defined($old_pwd));
		    
    setKeyValue($new_index, $old_pwd);
		
		my $new_hash = $defs{$new};
		
		delete($new_hash->{helper}{PWD_NEEDED});
		
		Log3 $new, 3, "todoist: device has been copied from $old to $new. Access-Token has been assigned to new device.";
}

sub todoist_Attr($@) {
  my ($cmd, $name, $attrName, $attrVal) = @_;
	
  my $orig = $attrVal;
	
	my $hash = $defs{$name};
	
	if ( $attrName eq "disable" ) {

		if ( $cmd eq "set" && $attrVal == 1 ) {
			if ($hash->{READINGS}{state}{VAL} ne "disabled") {
				readingsSingleUpdate($hash,"state","disabled",1);
				RemoveInternalTimer($hash,"todoist_GetTasks");
				RemoveInternalTimer($hash);
				Log3 $name, 4, "todoist ($name): $name is now disabled";
			}
		}
		elsif ( $cmd eq "del" || $attrVal == 0 ) {
			if ($hash->{READINGS}{state}{VAL} ne "active") {
				readingsSingleUpdate($hash,"state","active",1);
				RemoveInternalTimer($hash,"todoist_GetTasks");
				RemoveInternalTimer($hash);
				Log3 $name, 4, "todoist ($name): $name is now ensabled";
				InternalTimer(gettimeofday()+1, "todoist_GetTasks", $hash, 0);
			}
		}
	}
	
	if ( $attrName eq "pollInterval" ) {
		if ( $cmd eq "set" ) {
			return "$name: pollInterval has to be a number (seconds)" if ($attrVal!~ /\d+/);
			return "$name: pollInterval has to be greater than or equal 600" if ($attrVal < 60);
			$hash->{INTERVAL}=$attrVal;
			Log3 $name, 4, "todoist ($name): set new pollInterval to $attrVal";
		}
		elsif ( $cmd eq "del" ) {
			$hash->{INTERVAL}=1800;
			Log3 $name, 4, "todoist ($name): set new pollInterval to 1800 (standard)";
		}
		RemoveInternalTimer($hash,"todoist_GetTasks");
		InternalTimer(gettimeofday()+1, "todoist_GetTasks", $hash, 0) if (!IsDisabled($name) && IsDisabled($name) != 3);
	}
	
	if ( $attrName eq "sortTasks" ||  $attrName eq "showPriority") {
		if ( $cmd eq "set" ) {
			return "$name: $attrName has to be 0 or 1" if ($attrVal !~ /^(0|1)$/);
			Log3 $name, 4, "todoist ($name): set attribut $attrName to $attrVal";
		}
		elsif ( $cmd eq "del" ) {
			Log3 $name, 4, "todoist ($name): deleted attribut $attrName (standard)";
		}
		RemoveInternalTimer($hash,"todoist_GetTasks");
		InternalTimer(gettimeofday()+1, "todoist_GetTasks", $hash, 0) if (!IsDisabled($name) && IsDisabled($name) != 3);
	}
	
	if ( $attrName eq "getCompleted" ) {
		if ( $cmd eq "set" ) {
			return "$name: getCompleted has to be 0 or 1" if ($attrVal !~ /^(0|1)$/);
			Log3 $name, 4, "todoist ($name): set attribut getCompleted to $attrVal";
		}
		elsif ( $cmd eq "del" ) {
			Log3 $name, 4, "todoist ($name): deleted attribut getCompleted (standard)";
		}
		RemoveInternalTimer($hash,"todoist_GetTasks");
		InternalTimer(gettimeofday()+1, "todoist_GetTasks", $hash, 0) if (!IsDisabled($name) && IsDisabled($name) != 3);
	}
	
	return;
}

sub todoist_Set ($@) {
  my ($hash, $name, $cmd, @args) = @_;
	
	my @sets = ();
	
	push @sets, "active:noArg" if (IsDisabled($name));
	push @sets, "inactive:noArg" if (!IsDisabled($name));
	if (!IsDisabled($name) && !$hash->{helper}{PWD_NEEDED}) {
		push @sets, "addTask";
		push @sets, "completeTask";
		push @sets, "uncompleteTask";
		push @sets, "deleteTask";
		push @sets, "updateTask";
		push @sets, "clearList:noArg";
		push @sets, "getTasks:noArg";
		push @sets, "getUsers:noArg";
	}
	push @sets, "accessToken" if ($hash->{helper}{PWD_NEEDED});
	push @sets, "newAccessToken" if (!$hash->{helper}{PWD_NEEDED});
	
	return join(" ", @sets) if ($cmd eq "?");
	
	my $usage = "Unknown argument ".$cmd.", choose one of ".join(" ", @sets) if(scalar @sets > 0);
	
	if (IsDisabled($name) && $cmd !~ /^(active|inactive|.*ccessToken)?$/) {
		Log3 $name, 3, "todoist ($name): Device is disabled at set Device $cmd";
		return "Device is disabled. Enable it on order to use command ".$cmd;
	}
	
	if ( $cmd =~ /^(active|inactive)?$/ ) {   
		readingsSingleUpdate($hash,"state",$cmd,1);
		RemoveInternalTimer($hash,"todoist_GetTasks");
		CommandDeleteAttr(undef,"$name disable") if ($cmd eq "active" && AttrVal($name,"disable",0)==1);
		InternalTimer(gettimeofday()+1, "todoist_GetTasks", $hash, 0) if (!IsDisabled($name) && $cmd eq "active");
		Log3 $name, 3, "todoist ($name): set Device $cmd";
	}
	elsif ($cmd eq "getTasks") {
		RemoveInternalTimer($hash,"todoist_GetTasks");
		Log3 $name, 4, "todoist ($name): set getTasks manually. Timer restartet.";
		InternalTimer(gettimeofday()+1, "todoist_GetTasks", $hash, 0) if (!IsDisabled($name) && !$hash->{helper}{PWD_NEEDED});
	}
	elsif ($cmd eq "getUsers") {
		RemoveInternalTimer($hash,"todoist_GetUsers");
		Log3 $name, 4, "todoist ($name): set getUsers manually.";
		InternalTimer(gettimeofday()+1, "todoist_GetUsers", $hash, 0) if (!IsDisabled($name) && !$hash->{helper}{PWD_NEEDED});
	}
	elsif ($cmd eq "accessToken" || $cmd eq "newAccessToken") {
		return todoist_setPwd ($hash,$name,@args);
	}
	elsif ($cmd eq "addTask" || $cmd eq "newTask") {
		my $count=@args;
		if ($count!=0) {
			my $exp=decode_utf8(join(" ",@args));
			todoist_CreateTask ($hash,$exp);
		}
		return "new Task needs a title" if ($count==0);
	}
	elsif ($cmd eq "completeTask") {
		my $count=@args;
		if ($count!=0) {
			my $exp=decode_utf8(join(" ",@args));
			Log3 $name,5, "todoist ($name): Completed startet with exp: $exp";
			todoist_UpdateTask ($hash,$exp,"complete");
		}
		return "in order to complete a task, we need it's ID" if ($count==0);
	}
	elsif ($cmd eq "uncompleteTask") {
		my $count=@args;
		if ($count!=0) {
			my $exp=decode_utf8(join(" ",@args));
			Log3 $name,5, "todoist ($name): Uncompleted startet with exp: $exp";
			todoist_UpdateTask ($hash,$exp,"uncomplete");
		}
		return "in order to complete a task, we need it's ID" if ($count==0);
	}
	elsif ($cmd eq "updateTask") {
		my $count=@args;
		if ($count!=0) {
			my $exp=decode_utf8(join(" ",@args));
			todoist_UpdateTask ($hash,$exp,"update");
		}
		return "in order to complete a task, we need it's ID" if ($count==0);
	}
	elsif ($cmd eq "deleteTask") {
		my $count=@args;
		if ($count!=0) {
			my $exp=decode_utf8(join(" ",@args));
			todoist_UpdateTask ($hash,$exp,"delete");
		}
		return "in order to delete a task, we need it's ID" if ($count==0);
	}
	elsif ($cmd eq "sortTasks") {
		todoist_sort($hash);
	}
	elsif ($cmd eq "clearList") {
		todoist_clearList($hash);
	}
	else {
		return $usage;
	}

	return undef;
	
}

#####################################
# sets todoist Access Token
sub todoist_setPwd($$@) {
	my ($hash, $name, @pwd) = @_;
	 
	return "Password can't be empty" if (!@pwd);
	
	
	my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
  my $key = getUniqueId().$index;
	
	Log3 $name,5,"todoist ($name): unencoded pwd: $pwd[0]";
	
	my $pwdString=$pwd[0];

	$pwdString=encode_base64($pwdString);
	$pwdString =~ s/^\s+|\s+$//g;
	$pwdString =~ s/\n//g;
	
		 
	my $err = setKeyValue($index, $pwdString);
  
	return "error while saving the password - $err" if(defined($err));
  
	delete($hash->{helper}{PWD_NEEDED}) if(exists($hash->{helper}{PWD_NEEDED}));
	
	
	RemoveInternalTimer($hash,"todoist_GetTasks");
	
	if (AttrVal($name,"disable",0) != 1) {
		readingsSingleUpdate($hash,"state","active",1);
		InternalTimer(gettimeofday()+1, "todoist_GetTasks", $hash, 0);
	}
	
	Log3 $name, 3, "todoist ($name). New Password set.";
	
	return "password successfully saved";
	 
}

#####################################
# reads the Access Token and checks it
sub todoist_checkPwd ($$) {
	my ($hash, $pwd) = @_;
	my $name = $hash->{NAME};
    
  my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
  my $key = getUniqueId().$index;
	
	my ($err, $password) = getKeyValue($index);
        
  if ($err) {
		$hash->{helper}{PWD_NEEDED} = 1;
    Log3 $name, 3, "todoist ($name): unable to read password from file: $err";
    return undef;
  }  
	
	if ($password) {
		my $pw=decode_base64($password);
		
		return 1 if ($pw eq $pwd);
	}
	else {
		return "no password saved" if (!$password);
	}
	
	return 0;
}

sub todoist_Notify ($$) {
	my ($hash,$dev) = @_;
	
	my $name = $hash->{NAME};

  return if($dev->{NAME} ne "global");
	
  return if(!grep(m/^INITIALIZED|REREADCFG$/, @{$dev->{CHANGED}}));

  RemoveInternalTimer($hash, "todoist_GetTasks");
	InternalTimer(gettimeofday()+1, "todoist_GetTasks", $hash, 0) if (!IsDisabled($name) && !$hash->{helper}{PWD_NEEDED});

  return undef;

}


1;

=pod
=item summary    uses todoist API to add, read, complete and delete tasks in a  todoist tasklist
=item summary_DE Taskverwaltung einer todoist Taskliste über die todoist API
=begin html

<a name="todoist"></a>
<h3>todoist</h3>
<ul>
  A module to get a task list as readings from todoist. Tasks can be completed, updated and deleted.
	<br /><br />
	As preparation to use this module, you need to get your API Symbol (API ID) from the
	preferences of your account. 
	<br /><br />
	Notes:<br />
	<ul>
		<li>JSON, Data::Dumper, MIME::Base64, Date::Parse and Data::UUID have to be installed on the FHEM host.</li>
	</ul>
	<br /><br />
	<a name="todoist_Define"></a>
  <b>Define</b><br />
  <ul>
    <code>define &lt;name&gt; todoist &lt;PROJECT-ID&gt;</code><br />
    <br />
		<b>PROJECT-ID:</b> The ID of your project (=list).<br />
    <br /><br />

    Example:
    <ul>
      <code>define Einkaufsliste todoist 257528237</code><br />
    </ul>
  </ul><br />
	<br />
	<a name="todoist_Set"></a>
  <b>Set</b>
  <ul>
		<li><b>accessToken</b> - set the API Symbol for your todoist app</li><br />
		<li><b>active</b> - set the device active (starts the timer for reading task-list periodically)</li><br />
		<li><b>inactive</b> - set the device inactive (deletes the timer, polling is off)</li><br />
		<li><b>newAccessToken</b> - replace the saved token with a new one.</li><br />
		<li><b>getTasks</b> - get the task list immediately, reset timer.</li><br />
		<li><b>getUsers</b> - get the projects users immediately.</li><br />
		<li><b>addTask</b> - create a new task. Needs title as parameter.<br /><br />
		<code>set &lt;DEVICE&gt; addTask &lt;TASK_TITLE&gt;[:&lt;DUE_DATE&gt;]</code><br ><br />
		Additional Parameters are:<br />
		<ul>
		 <li>dueDate (due_date)=&lt;DUE_DATE&gt; (can be free form text or format: YYYY-MM-DDTHH:MM)</li>
		 <li>priority=the priority of the task (a number between 1 and 4, 4 for very urgent and 1 for natural).</li>
		</ul><br />
		Examples: <br /><br />
			<code>set &lt;DEVICE&gt; addTask &lt;TASK_TITLE&gt; dueDate=2017-01-15 priority=2</code><br /><br />
			<code>set &lt;DEVICE&gt; addTask &lt;TASK_TITLE&gt; dueDate=morgen</code><br /><br />
		<li><b>updateTask</b> - update a task. Needs Task-ID or todoist-Task-ID as parameter<br /><br />
		Possible additional parameters are:<br />
		<ul>
		 <li>dueDate (due_date)=&lt;DUE_DATE&gt; (can be free form text or format: YYYY-MM-DDTHH:MM)</li>
		 <li>priority=(1..4) (string)</li>
		 <li>title=&lt;TITLE&gt; (string)</li>
		</ul><br />
		Examples: <br /><br />
		<code>set &lt;DEVICE&gt; updateTask ID:12345678 dueDate=2017-01-15 priority=1</code><br />
		<code>set &lt;DEVICE&gt; updateTask 1 dueDate=übermorgen</code><br />
		
		<br /><br />
		<li><b>completeTask</b> - completes a task. Needs number of task (reading 'Task_NUMBER') or the 
		todoist-Task-ID (ID:<ID>) as parameter</li><br />
		<code>set &lt;DEVICE&gt; completeTask &lt;TASK-ID&gt;</code> - completes a task by number<br >
		<code>set &lt;DEVICE&gt; completeTask ID:&lt;todoist-TASK-ID&gt;</code> - completes a task by todoist-Task-ID<br ><br />
		<li><b>uncompleteTask</b> - uncompletes a Task. Use it like complete.<br />
		<li><b>deleteTask</b> - deletes a task. Needs number of task (reading 'Task_NUMBER') or the todoist-Task-ID (ID:<ID>) as parameter</li><br />
		<code>set &lt;DEVICE&gt; deleteTask &lt;TASK-ID&gt;</code> - deletes a task by number<br >
		<code>set &lt;DEVICE&gt; deleteTask ID:&lt;todoist-TASK-ID&gt;</code> - deletes a task by todoist-Task-ID<br ><br />
		<li><b>sortTasks</b> - sort Tasks alphabetically<br /><br />
		<li><b>clearList</b> - <b><u>deletes</u></b> all Tasks from the list (only FHEM listed Tasks can be deleted)
	</ul>
	<br />
	<a name="todoist_Attributes"></a>
  <b>Attributes</b><br />
  <ul>
		<li><a href="#readingFnAttributes">readingFnAttributes</a></li><br />
		<li><a href="#do_not_notify">do_not_notify</a></li><br />
    <li><a name="#disable">disable</a></li><br />
		<li>pollInterval</li>
		get the list every pollInterval seconds. Default is 1800. Smallest possible value is 60.<br /><br />
		<li>sortTasks</li>
		<ul>
		<li>0: don't sort the tasks (default)</li>
		<li>1: sorts Tasks alphabetically after every update</li>
		<!--<li>2: sorts Tasks in todoist order</li>-->
		</ul>
		<br />
		<li>showPriority</li>
		<ul>
		<li>0: don't show priority (default)</li>
		<li>1: show priority</li>
		</ul>
		<br />
		<li>getCompleted</li>
		<ul>
		<li>0: don't get completet tasks (default)</li>
		<li>1: get completed tasks</li>
		</ul><br />
		<b>ATTENTION: Only premium users have	access to completed tasks!</b>
		<br /><br />
		<li>autoGetUsers</li>
		<ul>
		<li>0: don't get users automatically</li>
		<li>1: get users after every "getTasks" (default)</li>
		</ul>
		<br /><br />
	</ul><br />
	
	<a name="todoist_Readings"></a>
  <b>Readings</b><br />
  <ul>
		<li>Task_XXX<br />
      the tasks are listet as Task_000, Task_001 [...].</li><br />
		<li>Task_XXX_dueDate<br />
      if a task has a due date, this reading should be filled with the date.</li><br />
    <li>Task_XXX_priority<br />
      the priority of your task.</li><br />
		<li>Task_XXX_ID<br />
      the todoist ID of Task_X.</li><br />
		<li>Task_XXX_completedAt<br />
      only for completed Tasks (attribute getCompleted).</li><br />
		<li>Task_XXX_completedById<br />
      only for completed Tasks (attribute getCompleted).</li><br />
    <li>Task_XXX_assignedByUid<br />
      the user this task was assigned by.</li><br />
		<li>Task_XXX_responsibleUid<br />
      the user this task was assigned to.</li><br />
		<li>User_XXX<br />
      the lists users are listet as User_000, User_001 [...].</li><br />
		<li>User_XXX_ID<br />
      the users todoist ID.</li><br />
		<li>listText<br />
      a comma seperated list of tasks in the specified list. This may be used for TTS, Messages etc.</li><br />
		<li>count<br />
      number of Tasks in list.</li><br />
		<li>error<br />
      current error. Default is none.</li><br />
		<li>lastCompletedTask<br />
      title of the last completed task.</li><br />
		<li>lastCreatedTask<br />
      title of the last created task.</li><br />
		<li>lastDeletedTask<br />
      title of the last deleted task.</li><br />
		<li>lastError<br />
      last Error.</li><br />
		<li>state<br />
			state of the todoist-Device</li>
  </ul><br />
</ul>

=end html
=cut