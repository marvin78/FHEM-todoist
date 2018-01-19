# $Id: 98_wunderlist.pm 3900 2018-01-18 16:18:10Z marvin1978 $

package main;

use strict;
use warnings;
use Data::Dumper; 
use JSON;
use MIME::Base64;
use Encode;

#######################
# Global variables
my $version = "1.0.3";

my %gets = (
  "version:noArg"     => "",
); 


sub wunderlist_Initialize($) {
  my ($hash) = @_;

  $hash->{SetFn}    = "wunderlist_Set";
  $hash->{GetFn}    = "wunderlist_Get";
	$hash->{DefFn}    = "wunderlist_Define";
	$hash->{UndefFn}  = "wunderlist_Undefine";
	$hash->{AttrFn}   = "wunderlist_Attr";
	$hash->{RenameFn} = "wunderlist_Rename";   
	$hash->{CopyFn}	  = "wunderlist_Copy";
	$hash->{DeleteFn} = "wunderlist_Delete";
	$hash->{NotifyFn} = "wunderlist_Notify";
	
  $hash->{AttrList} = "disable:1,0 ".
											"pollInterval ".
											"do_not_notify ".
											"sortTasks:1,2,0 ".
											"getCompleted:1,0 ".
											"avoidDuplicates:1,0 ".
											"listDivider ".
											$readingFnAttributes;
	
	return undef;
}

sub wunderlist_Define($$) {
  my ($hash, $def) = @_;
	my $now = time();
	my $name = $hash->{NAME}; 
  
	
	my @a = split( "[ \t][ \t]*", $def );
	
	if ( int(@a) < 3 ) {
    my $msg =
"Wrong syntax: define <name> wunderlist CLIENT-ID List-ID";
    Log3 $name, 4, $msg;
    return $msg;
  }
	

	## set internal variables
	$hash->{CLIENTID}=$a[2];
	$hash->{LISTID}=$a[3];
	$hash->{INTERVAL}=AttrVal($name,"pollInterval",undef)?AttrVal($name,"pollInterval",undef):1800;
	$hash->{VERSION}=$version;
	
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
		RemoveInternalTimer($hash,"wunderlist_GetTasks");
		wunderlist_GetTasks($hash) if (!IsDisabled($name) && !$hash->{helper}{PWD_NEEDED});
	}
	
	return undef;
}

sub wunderlist_GetPwd($) {
	my ($hash) = @_;
	
	my $name=$hash->{NAME};
	
	my $pwd="";
	
	my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
	my $key = getUniqueId().$index;
	
	my ($err, $password) = getKeyValue($index);
				
	if ($err) {
		$hash->{helper}{PWD_NEEDED} = 1;
		Log3 $name, 4, "wunderlist ($name): unable to read password from file: $err";
		return undef;
	}	  
	
	if ($password) {
		$pwd=decode_base64($password);
	}
	
	return undef if ($pwd eq "");
	
	return $pwd;
}

## set error Readings
sub wunderlist_ErrorReadings($$) {
	my ($hash,$errorText) = @_;
	
	my $name = $hash->{NAME};

	readingsBeginUpdate( $hash );
	readingsBulkUpdate( $hash,"error",$errorText );
	readingsBulkUpdate( $hash,"lastError",$errorText );
	readingsEndUpdate( $hash, 1 );
	
	Log3 $name,3, "wunderlist ($name): ".$errorText;
	return undef;
}


# update Task
sub wunderlist_UpdateTask($$$) {
	my ($hash,$cmd, $type) = @_;
	
	my($a, $h) = parseParams($cmd);
	
	my $name=$hash->{NAME};
	
	my $param;
	
	my $pwd="";
	
	my %datas=();
	
	my $method;
	my $urlPart;
	my $taskId;
	my $title;
	
	## get Task-ID
	my $tid = @$a[0];
	
	## check if ID is wunderlist ID
	my @temp=split(":",$tid);
	
	
	## use the wunderlist ID
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
	

	## if no token is needed and device is not disabled, check token and get list vom wunderlist
	if (!$hash->{helper}{PWD_NEEDED} && !IsDisabled($name)) {
		
		## get password
		$pwd=wunderlist_GetPwd($hash);
		
		if ($pwd) {
			Log3 $name,5, "$name: hash: ".Dumper($hash);
			
			## complete a task
			if ($type eq "complete") {
				# data array for API - we could transfer more data
				%datas = (
										"revision" 					=> int($hash->{helper}{"REV"}{$taskId}),
										"completed"      		=> \1,
				);
				$method="PATCH";
				$urlPart=$taskId;
			}
			## update a task 
			elsif ($type eq "update") {
				%datas = (
										"revision" 					=> int($hash->{helper}{"REV"}{$taskId}),
				);
				
				## change title
				$datas{'title'} = $h->{"title"} if($h->{'title'});
				## change dueDate
				$datas{'due_date'} = $h->{"dueDate"} if($h->{'dueDate'});
				## change dueDate (if someone uses due_date in stead of dueDate)
				$datas{'due_date'} = $h->{"due_date"} if ($h->{'due_date'});
				## change assignee_id
				$datas{'assignee_id'} = int($h->{"assignee_id"}) if ($h->{"assignee_id"});
				## change starred
				$datas{'starred'} = \1 if ($h->{"starred"} && ($h->{"starred"} eq 'true' || int($h->{"starred"}) == 1));
				$datas{'starred'} = \0 if ($h->{"starred"} && $h->{"starred"} eq 'false');
				## change completed
				$datas{'completed'} = \1 if ($h->{"completed"} && ($h->{"completed"} eq 'true' || int($h->{"completed"}) == 1));
				$datas{'completed'} = \0 if ($h->{"completed"} && $h->{"completed"} eq 'false');
				## change recurrence type
				if ($h->{"recurrence_type"}) {
					$datas{'recurrence_type'} = $h->{"recurrence_type"};
					## set recurrence type to 1 if parameter not set
					if (!$h->{"recurrence_count"} || int($h->{"recurrence_count"}) < 1) {
						$datas{'recurrence_count'} = 1;
					}
					else {
						$datas{'recurrence_count'} = int($h->{"recurrence_count"});
					}
				}
				
				## change recurrence count
				if ($h->{"recurrence_count"} && !$h->{"recurrence_type"}) {
					my $recType = ReadingsVal($name,"Task_".sprintf('%03d',$hash->{helper}{"WID"}{$taskId})."_recurrenceType","-");
					if ($recType ne "-") {
						$datas{'recurrence_type'} = $recType;
						$datas{'recurrence_count'} = int($h->{"recurrence_count"});
					}
				}
					
				## remove attribute
				if ($h->{"remove"}) {
					my @temp;
					my @rem = split(",",$h->{"remove"});
					foreach my $r (@rem) {
						$r = "due_date" if ($r eq "dueDate");
						push @temp,$r;
					}
					$datas{'remove'} = \@temp;
					## Debug
					#Log3 $name, 1, "wunderlist ($name): Debug: ".Dumper($datas{'remove'});
				}
				## Debug
				#Log3 $name, 1, "wunderlist ($name): Debug: ".Dumper(%datas);
				
				$method="PATCH";
				$urlPart=$taskId;
			}
			## delete a task
			elsif ($type eq "delete") {
				# data array for API
				%datas = (
										"revision" 					=> int($hash->{helper}{"REV"}{$taskId}),
				);
				$method="DELETE";
				$urlPart=$taskId."?revision=".int($hash->{helper}{"REV"}{$taskId});
			}
			else {
				return undef;
			}
			
			Log3 $name,5, "wunderlist ($name): Data Array sent to wunderlist API: ".Dumper(%datas);
		
			my $data=encode_json(\%datas);
			
			Log3 $name,4, "wunderlist ($name): JSON sent to wunderlist API: ".Dumper($data);
			
			$param = {
				url        => "https://a.wunderlist.com/api/v1/tasks/".$urlPart,
				data			 => $data,
				tTitle		 => $title,
				method		 => $method,
				wType			 => $type,
				taskId		 => $taskId,
				timeout    => 7,
				header 		 => {
					"X-Access-Token" => $pwd,
					"X-Client-ID"    => $hash->{CLIENTID},
					"Content-Type"   => "application/json",
				},
				hash 			 => $hash,
				callback   => \&wunderlist_HandleTaskCallback,  ## call callback sub to work with the data we get
			};
			
			Log3 $name,5, "wunderlist ($name): Param: ".Dumper($param);
			
			## non-blocking access to wunderlist API
			InternalTimer(gettimeofday()+1, "HttpUtils_NonblockingGet", $param, 0);
		}
		else {
			wunderlist_ErrorReadings($hash,"access token empty");
		}
	}
	else {
		if (!IsDisabled($name)) {
			wunderlist_ErrorReadings($hash,"no access token set");
		}
		else {
			wunderlist_ErrorReadings($hash,"device is disabled");
		}
	
	}
	
	return undef;
}

# create Task
sub wunderlist_CreateTask($$) {
	my ($hash,$cmd) = @_;
	
	my($a, $h) = parseParams($cmd);
	
	my $name=$hash->{NAME};
	
	my $param;
	
	my $pwd="";
	
	my $assigne_id="";
	
	## we try to send a due_date (in developement)
	my @tmp = split( ":", join(" ",@$a) );
	
	my $title=encode_utf8($tmp[0]);
	
	my $check=1;
	
	if (AttrVal($name,"avoidDuplicates",0) == 1 && wunderlist_inArray(\@{$hash->{helper}{"TITS"}},$title)) {
		$check=-1;
	}
	
	if ($check==1) {
	
		## if no token is needed and device is not disabled, check token and get list vom wunderlist
		if (!$hash->{helper}{PWD_NEEDED} && !IsDisabled($name)) {
			
			## get password
			$pwd=wunderlist_GetPwd($hash);
			
			if ($pwd) {
			
				Log3 $name,5, "$name: hash: ".Dumper($hash);
				
				# data array for API - we could transfer more data
				my %datas = ("list_id"         		=> int($hash->{LISTID}),
										 "title"          		=> $title,
				);
				
				## check for dueDate as Parameter or part of title - push to hash
				if (!$tmp[1] && $h->{"dueDate"}) { ## parameter
					$datas{'due_date'} = $h->{"dueDate"};
				}
				elsif ($tmp[1]) { ## title
					$datas{'due_date'} = $tmp[1];
				}
				else {
				
				}
				
				## if someone uses due_date - no problem
				$datas{'due_date'} = $h->{"due_date"} if ($h->{"due_date"});
				
				## check for recurrence type - push to hash
				if ($h->{"recurrence_type"}) {
					$datas{'recurrence_type'} = $h->{"recurrence_type"} if ($h->{"recurrence_type"});
					## set recurrence type to 1 if parameter not set
					if (!$h->{"recurrence_count"} || int($h->{"recurrence_count"}) < 1) {
						$datas{'recurrence_count'} = 1;
					}
					else {
						$datas{'recurrence_count'} = int($h->{"recurrence_count"});
					}
				}
				
				## Task is starred? Push it to hash
				$datas{'starred'} = \1 if ($h->{"starred"} && (int($h->{"starred"}) == 1 ||  $h->{"starred"} eq "true"));
				
				## Assignee set? push to hash
				$datas{'assignee_id'} = $h->{"assignee_id"}?int($h->{"assignee_id"}):undef;
				
				
				Log3 $name,5, "wunderlist ($name): Data Array sent to wunderlist API: ".Dumper(%datas);
			
				my $data=encode_json(\%datas);
				
				Log3 $name,4, "wunderlist ($name): JSON sent to wunderlist API: ".Dumper($data);
				
				$param = {
					url        => "https://a.wunderlist.com/api/v1/tasks?list_id=".int($hash->{LISTID}),
					data			 => $data,
					tTitle		 => $title,
					method		 => "POST",
					wType			 => "create",
					timeout    => 7,
					header 		 => {
						"X-Access-Token" => $pwd,
						"X-Client-ID"    => $hash->{CLIENTID},
						"Content-Type"   => "application/json",
					},
					hash 			 => $hash,
					callback   => \&wunderlist_HandleTaskCallback,  ## call callback sub to work with the data we get
				};
				
				Log3 $name,5, "wunderlist ($name): Param: ".Dumper($param);
				
				## non-blocking access to wunderlist API
				InternalTimer(gettimeofday()+1, "HttpUtils_NonblockingGet", $param, 0);
			}
			else {
				wunderlist_ErrorReadings($hash,"access token empty");
			}
		}
		else {
			if (!IsDisabled($name)) {
				wunderlist_ErrorReadings($hash,"no access token set");
			}
			else {
				wunderlist_ErrorReadings($hash,"device is disabled");
			}
		}
	}
	else {
		map {FW_directNotify("#FHEMWEB:$_", "if (typeof wunderlist_ErrorDialog === \"function\") wunderlist_ErrorDialog('$title is already on the list')", "")} devspec2array("WEB.*");
		wunderlist_ErrorReadings($hash,"duplicate detected");
	}	
	
	
	return undef;
}

sub wunderlist_HandleTaskCallback($$$){
	my ($param, $err, $data) = @_;
	
	my $hash = $param->{hash};
	my $title = $param->{tTitle};
	
	my $taskId = $param->{taskId} if ($param->{taskId});
	
	my $reading = $title;
	
	my $name = $hash->{NAME}; 
	
	Log3 $name,5, "wunderlist ($name):  ".$param->{wType}."Task Callback data: ".Dumper($data);

	
	readingsBeginUpdate($hash);
	
	## if "created at" in $data, we were successfull
	if($data =~ /created_at/ || $data =~ /completed/ || $data eq "") {
	
		if ($data ne "") {
			my @decoded_json = decode_json($data);
			
			$taskId = $decoded_json[0]{id} if ($decoded_json[0]{id});
			
			$reading .= " - ".$decoded_json[0]{id} if ($decoded_json[0]{id});
			
			## do some logging
			Log3 $name,5, "wunderlist ($name):  Task Callback data (decoded JSON): ".Dumper(@decoded_json );
			
			Log3 $name,4, "wunderlist ($name): Callback-ID: $decoded_json[0]{id}";
		}
		Log3 $name,4, "wunderlist ($name):  Task Callback error(s): ".Dumper($err);
		Log3 $name,5, "wunderlist ($name):  Task Callback param: ".Dumper($param);
		
		readingsBulkUpdate($hash, "error","none");
		readingsBulkUpdate($hash, "lastCreatedTask",$reading) if ($param->{wType} eq "create");
		readingsBulkUpdate($hash, "lastCompletedTask",$reading) if ($param->{wType} eq "complete");
		readingsBulkUpdate($hash, "lastUpdatedTask",$reading) if ($param->{wType} eq "update");
		readingsBulkUpdate($hash, "lastDeletedTask",$reading) if ($param->{wType} eq "delete");
		
		## some Logging
		Log3 $name, 4, "wunderlist ($name): successfully created new task $title" if ($param->{wType} eq "create");
		Log3 $name, 4, "wunderlist ($name): successfully ".$param->{wType}."ed task $title";
		
		if ($param->{wType} =~ /(complete|delete)/) {
			map {FW_directNotify("#FHEMWEB:$_", "if (typeof wunderlist_removeLine === \"function\") wunderlist_removeLine('$name','$taskId')", "")} devspec2array("WEB.*");
		}
		if ($param->{wType} eq "create") {
			map {FW_directNotify("#FHEMWEB:$_", "if (typeof wunderlist_addLine === \"function\") wunderlist_addLine('$name','$taskId','$title')", "")} devspec2array("WEB.*");
		}
	}
	## we got an error from the API
	else {
		my @decoded_json = decode_json($data);
		foreach my $error (@decoded_json) {
				my $errorType=$error->{error}{type}?$error->{error}{type}:"";
				readingsBulkUpdate($hash, "error",$errorType);
				readingsBulkUpdate($hash, "lastError",$errorType);
				Log3 $name, 4, "wunderlist ($name): got error: ".$errorType;
			Log3 $name, 4, "wunderlist ($name): got error: ".$error->{error}{type};
	  }
	}
	
  readingsEndUpdate( $hash, 1 );
	
	
	wunderlist_RestartGetTimer($hash);
	
	return undef;
}


## get all Users
sub wunderlist_GetUsers($) {
	my ($hash) = @_;
	
	my $name=$hash->{NAME};
	
	my $param;
	
	my $pwd="";
	
	## if no token is needed and device is not disabled, check token and get list vom wunderlist
	if (!$hash->{helper}{PWD_NEEDED} && !IsDisabled($name)) {
		
		## get password
		$pwd=wunderlist_GetPwd($hash);
		
		my %datas = ("list_id"         		=> int($hash->{LISTID}),
		);
		my $data=encode_json(\%datas);
		
		if ($pwd) {
		
			Log3 $name,5, "$name: hash: ".Dumper($hash);
			
			$param = {
				url        => "https://a.wunderlist.com/api/v1/users",
				data			 => $data,
				timeout    => 7,
				method		 => "GET",
				header 		 => {
					"X-Access-Token" => $pwd,
					"X-Client-ID" => $hash->{CLIENTID},
				},
				hash 			 => $hash,
				callback   => \&wunderlist_GetUsersCallback,  ## call callback sub to work with the data we get
			};
			
			
			Log3 $name,5, "wunderlist ($name): Param: ".Dumper($param);
			
			## non-blocking access to wunderlist API
			InternalTimer(gettimeofday()+1, "HttpUtils_NonblockingGet", $param, 0);
		}
		else {
			wunderlist_ErrorReadings($hash,"access token empty");
		}
	}
	else {
		if (!IsDisabled($name)) {
			wunderlist_ErrorReadings($hash,"no access token set");
		}
		else {
			wunderlist_ErrorReadings($hash,"device is disabled");
		}
	}
	
	return undef;
}

sub wunderlist_GetUsersCallback($$$){
	my ($param, $err, $data) = @_;
	
	my $hash=$param->{hash};
	
	my $name = $hash->{NAME}; 
	
	Log3 $name,5, "wunderlist ($name): User Callback data: ".Dumper($data);
	
	my $lText="";
	
	readingsBeginUpdate($hash);
	
	## did we get JSON in an array? That would mean, we got task data
	if(eval {\@{decode_json($data)}}) {
	
		my @decoded_json = @{decode_json($data)};
		
		
		## do some logging
		Log3 $name,5, "wunderlist ($name):  User Callback data (decoded JSON): ".Dumper(@decoded_json );
		Log3 $name,4, "wunderlist ($name):  User Callback error(s): ".Dumper($err);
		Log3 $name,5, "wunderlist ($name):  User Callback param: ".Dumper($param);
		
		my $i=0;
		
		## count the results
		my $count=@decoded_json;
		
		## delete Task_* readings for changed list
		CommandDeleteReading(undef, "$hash->{NAME} (U|u)ser_.*");
		delete($hash->{helper}{USER});

		
		
		## no data
		if ($count==0) {
			readingsBulkUpdate($hash, "error","no data");
			readingsBulkUpdate($hash, "lastError","no data");
			readingsBulkUpdate($hash, "countUsers",0);
		}
		else {
			foreach my $user (@decoded_json) {
				my $userName = encode_utf8($user->{name});
				my $t = sprintf ('%03d',$i);
				
				## get wunderlist-User-ID
				my $userID = $user->{id};
				
				readingsBulkUpdate($hash, "User_".$t,$userName);
				readingsBulkUpdate($hash, "User_".$t."_ID",$userID);

				## a few helper for ID and revision
				$hash->{helper}{USER}{"IDS"}{"User_".$i}=$userID;
				$hash->{helper}{USER}{"NAME"}{$userID}=$userName;
				$hash->{helper}{USER}{"WID"}{$userID}=$i;
				
				$i++;
			}
			readingsBulkUpdate($hash, "error","none");
			readingsBulkUpdate($hash, "countUsers",$i);
			
		}
	}
	## we got an error from the API
	else {
		eval {
			my @decoded_json = decode_json($data);
			foreach my $error (@decoded_json) {
				my $errorType=$error->{error}{type}?$error->{error}{type}:"";
				readingsBulkUpdate($hash, "error",$errorType);
				readingsBulkUpdate($hash, "lastError",$errorType);
				Log3 $name, 4, "wunderlist ($name): got error: ".$errorType;
			}
			1;
		}
		or do { ## we got HTML instead of JSON - mostly this is the case, if token is wrong
			readingsBulkUpdate($hash, "error","malformed JSON / Access Token wrong or API access gone");
			Log3 $name,3, "wunderlist ($name): No access. Token seems to be wrong or we can't get access. Got malformed JSON";
			#readingsBulkUpdate($hash,"state","inactive");
		}
	}

	
	readingsEndUpdate( $hash, 1 );
	
	return undef;
}


## get all Tasks
sub wunderlist_GetTasks($;$) {
	my ($hash,$completed) = @_;
	
	my $name=$hash->{NAME};
	
	$completed = 0 unless defined($completed);
	
	my $param;
	my $param2;
	
	my $pwd="";
	
	## if no token is needed and device is not disabled, check token and get list vom wunderlist
	if (!$hash->{helper}{PWD_NEEDED} && !IsDisabled($name)) {
		
		## get password
		$pwd=wunderlist_GetPwd($hash);
		
		if ($pwd) {
		
			Log3 $name,5, "$name: hash: ".Dumper($hash);
			
			## check if we get also the completed Tasks
			my $urlComp = "";
			
			if ($completed == 1) {
				$urlComp = "&completed=true";
			}
			
			## get the tasks
			$param = {
				url        => "https://a.wunderlist.com/api/v1/tasks?list_id=".$hash->{LISTID}.$urlComp,
				timeout    => 7,
				header 		 => {
					"X-Access-Token" => $pwd,
					"X-Client-ID" => $hash->{CLIENTID},
				},
				completed  => $completed,
				hash 			 => $hash,
				callback   => \&wunderlist_GetTasksCallback,  ## call callback sub to work with the data we get
			};
			
			
			Log3 $name,5, "wunderlist ($name): Param: ".Dumper($param);
			
			## non-blocking access to wunderlist API
			InternalTimer(gettimeofday()+0.4, "HttpUtils_NonblockingGet", $param, 0);
			
			
		}
		else {
			wunderlist_ErrorReadings($hash,"access token empty");
		}
	}
	else {
		if (!IsDisabled($name)) {
			wunderlist_ErrorReadings($hash,"no access token set");
		}
		else {
			wunderlist_ErrorReadings($hash,"device is disabled");
		}
	}
	
	## one more time, if completed
	if (AttrVal($name,"getCompleted",undef) && $completed != 1) {		
		InternalTimer(gettimeofday()+0.1, "wunderlist_doGetCompTasks", $hash, 0);
	}
	InternalTimer(gettimeofday()+2, "wunderlist_GetUsers", $hash, 0) if ($completed != 1);
	
	return undef;
}

sub wunderlist_doGetCompTasks($) {
	my ($hash) = @_;
	wunderlist_GetTasks($hash,1);
}

## Callback for the lists tasks
sub wunderlist_GetTasksCallback($$$){
	my ($param, $err, $data) = @_;
	
	my $hash=$param->{hash};
	
	my $name = $hash->{NAME}; 
	
	Log3 $name,5, "wunderlist ($name):  Task Callback data: ".Dumper($data);
	
	my $lText="";
	
	readingsBeginUpdate($hash);
	
	## did we get JSON in an array? That would mean, we got task data
	if(eval {\@{decode_json($data)}}) {
	
		my @decoded_json = @{decode_json($data)};
		
		
		## do some logging
		Log3 $name,5, "wunderlist ($name):  Task Callback data (decoded JSON): ".Dumper(@decoded_json );
		Log3 $name,4, "wunderlist ($name):  Task Callback error(s): ".Dumper($err);
		Log3 $name,5, "wunderlist ($name):  Task Callback param: ".Dumper($param);
		
		my $i=0;
		
		## count the results
		my $count=@decoded_json;
		
		## delete Task_* readings for changed list
		if ($param->{completed} != 1 || (ReadingsVal($name,"count",0)==0 && $count == 0)) {
			CommandDeleteReading(undef, "$hash->{NAME} (T|t)ask_.*");
			delete($hash->{helper});
		}

		
		
		## no data
		if ($count==0 && $param->{completed} != 1) {
			readingsBulkUpdate($hash, "error","no data");
			readingsBulkUpdate($hash, "lastError","no data");
			readingsBulkUpdate($hash, "count",0);
		}
		else {
			$i = ReadingsVal($name,"count",0) if ($param->{completed} == 1);
			foreach my $task (@decoded_json) {
				my $title = encode_utf8($task->{title});
				$title =~ s/^\s+|\s+$//g;
				
				my $t = sprintf ('%03d',$i);
				
				## get wunderlist-Task-ID
				my $taskID = $task->{id};
				
				readingsBulkUpdate($hash, "Task_".$t,$title);
				readingsBulkUpdate($hash, "Task_".$t."_ID",$taskID);

				## a few helper for ID and revision
				$hash->{helper}{"IDS"}{"Task_".$i}=$taskID;
				$hash->{helper}{"REV"}{$taskID}=$task->{revision};
				$hash->{helper}{"TITLE"}{$taskID}=$title;
				$hash->{helper}{"WID"}{$taskID}=$i;
				push @{$hash->{helper}{"TIDS"}},$taskID; # simple ID list
				push @{$hash->{helper}{"TITS"}},$title; # simple ID list
				
				## set due_date if present
				if (defined($task->{completed_at})) {
					## if there is a completed task, we create a new reading
					readingsBulkUpdate($hash, "Task_".$t."_completedAt",$task->{completed_at});
					$hash->{helper}{"COMPLETED_AT"}{$taskID}=$task->{completed_at};
					readingsBulkUpdate($hash, "Task_".$t."_completedById",$task->{completed_by_id});
					$hash->{helper}{"COMPLETED_BY_ID"}{$taskID}=$task->{completed_by_id};
				}
				
				## set due_date if present
				if (defined($task->{due_date})) {
					## if there is a task with due date, we create a new reading
					readingsBulkUpdate($hash, "Task_".$t."_dueDate",$task->{due_date});
					$hash->{helper}{"DUE_DATE"}{$taskID}=$task->{due_date};
				}
				
				## set assignee_id if present
				if (defined($task->{assignee_id})) {
					## if there is a task with assignee_id, we create a new reading
					readingsBulkUpdate($hash, "Task_".$t."_assigneeId",$task->{assignee_id});
					$hash->{helper}{"ASSIGNEE_ID"}{$taskID}=$task->{assignee_id};
				}
				
				## set starred if present
				if (defined($task->{starred})) {
					## if there is a starred task, we create a new reading
					my $star = $task->{starred}?1:undef;
					readingsBulkUpdate($hash, "Task_".$t."_starred",$star);
					$hash->{helper}{"STARRED"}{$taskID}=$star;
				}
				
				## set recurrence_type and count if present
				if (defined($task->{recurrence_type})) {
					## if there is a task with recurrence_type, we create new readings
					readingsBulkUpdate($hash, "Task_".$t."_recurrenceType",$task->{recurrence_type});
					$hash->{helper}{"RECURRENCE_TYPE"}{$taskID}=$task->{recurrence_type};
					readingsBulkUpdate($hash, "Task_".$t."_recurrenceCount",$task->{recurrence_count});
					$hash->{helper}{"RECURRENCE_COUNT"}{$taskID}=$task->{recurrence_count};
				}
				
				if ($param->{completed} != 1) {
					$lText.=AttrVal($name,"listDivider",", ") if ($i != 0);
					$lText.=$title;
				}
				$i++;
			}
			readingsBulkUpdate($hash, "error","none");
			readingsBulkUpdate($hash, "count",$i);
			
			if (AttrVal($name,"sortTasks",0) == 2) {
				my $pwd=wunderlist_GetPwd($hash);
				## get the lists positions
				my $param = {
					url        => "https://a.wunderlist.com/api/v1/task_positions?list_id=".$hash->{LISTID},
					timeout    => 7,
					header 		 => {
						"X-Access-Token" => $pwd,
						"X-Client-ID" => $hash->{CLIENTID},
					},
					hash 			 => $hash,
					callback   => \&wunderlist_GetListPositionsCallback,  ## call callback sub to work with the data we get
				};
				
				
				Log3 $name,5, "wunderlist ($name): Param: ".Dumper($param);
				
				## non-blocking access to wunderlist API
				InternalTimer(gettimeofday()+0.2, "HttpUtils_NonblockingGet", $param, 0);
			}
			
		}
	}
	## we got an error from the API
	else {
		eval {
			my @decoded_json = decode_json($data);
			foreach my $error (@decoded_json) {
				my $errorType=$error->{error}{type}?$error->{error}{type}:"";
				readingsBulkUpdate($hash, "error",$errorType);
				readingsBulkUpdate($hash, "lastError",$errorType);
				Log3 $name, 4, "wunderlist ($name): got error: ".$errorType;
			}
			1;
		}
		or do { ## we got HTML instead of JSON - mostly this is the case, if token is wrong
			readingsBulkUpdate($hash, "error","malformed JSON / Access Token wrong or API access gone");
			Log3 $name,3, "wunderlist ($name): No access. Token seems to be wrong or we can't get access. Got malformed JSON";
			#readingsBulkUpdate($hash,"state","inactive");
		}
	}
	## list Text for TTS, Text-Message...
	if ($param->{completed} != 1) {
		$lText="-" if ($lText eq "");
		readingsBulkUpdate($hash,"listText",$lText) if ($lText ne "");
	}
	
	
	readingsEndUpdate( $hash, 1 );
	
	## sort Tasks alphabetically if set
	wunderlist_sort($hash) if (AttrVal($name,"sortTasks",0) == 1);
	
	
	RemoveInternalTimer($hash,"wunderlist_GetTasks");
	InternalTimer(gettimeofday()+$hash->{INTERVAL}, "wunderlist_GetTasks", $hash, 0); ## loop with Interval
	
	return undef;
}

## Callback for the tasks positions
sub wunderlist_GetListPositionsCallback($$$){
	my ($param, $err, $data) = @_;
	
	my $hash=$param->{hash};
	
	my $name = $hash->{NAME}; 
	
	Log3 $name,5, "wunderlist ($name):  Task Positions Callback data: ".Dumper($data);
	
	my $lText="";
	
	readingsBeginUpdate($hash);
	
	## did we get JSON in an array? That would mean, we got task data
	if(eval {\@{decode_json($data)}}) {
	
		my @decoded_json = @{decode_json($data)};
		
		
		## do some logging
		Log3 $name,5, "wunderlist ($name):  Task Callback Positions data (decoded JSON): ".Dumper(@decoded_json );
		Log3 $name,4, "wunderlist ($name):  Task Callback Positions error(s): ".Dumper($err);
		Log3 $name,5, "wunderlist ($name):  Task Callback Positions param: ".Dumper($param);
		
		my $i=0;
		
		## count the results
		my $count=@decoded_json;
		
				
		## no data
		if ($count==0 && $param->{completed} != 1) {
			readingsBulkUpdate($hash, "error","no data");
			readingsBulkUpdate($hash, "lastError","no data");
		}
		else {
			foreach my $task (@decoded_json) {
				
				$hash->{helper}{"POSITIONS"} = $task->{values};
				
			}
			readingsBulkUpdate($hash, "error","none");
			
		}
	}
	## we got an error from the API
	else {
		eval {
			my @decoded_json = decode_json($data);
			foreach my $error (@decoded_json) {
				my $errorType=$error->{error}{type}?$error->{error}{type}:"";
				readingsBulkUpdate($hash, "error",$errorType);
				readingsBulkUpdate($hash, "lastError",$errorType);
				Log3 $name, 4, "wunderlist ($name): got error: ".$errorType;
			}
			1;
		}
		or do { ## we got HTML instead of JSON - mostly this is the case, if token is wrong
			readingsBulkUpdate($hash, "error","malformed JSON / Access Token wrong or API access gone");
			Log3 $name,3, "wunderlist ($name): No access. Token seems to be wrong or we can't get access. Got malformed JSON";
			#readingsBulkUpdate($hash,"state","inactive");
		}
	}
	
	## sort Tasks by wunderlist order if set
	wunderlist_sortWunderlist($hash) if (AttrVal($name,"sortTasks",0) == 2);
	
	readingsEndUpdate( $hash, 1 );
	
	return undef;
}

## sort alphabetically
sub wunderlist_sort($) {
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
			my $rev = $hash->{helper}{"REV"}{"Task_".$tid};
			$list{$tid} = {content => $val, ID => $id, REV => $rev};
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
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_assigneeId",$hash->{helper}{"ASSIGNEE_ID"}{$data->{ID}}) if ($hash->{helper}{"ASSIGNEE_ID"}{$data->{ID}});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_starred",$hash->{helper}{"STARRED"}{$data->{ID}}) if ($hash->{helper}{"STARRED"}{$data->{ID}});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_recurrenceType",$hash->{helper}{"RECURRENCE_TYPE"}{$data->{ID}}) if ($hash->{helper}{"RECURRENCE_TYPE"}{$data->{ID}});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_recurrenceCount",$hash->{helper}{"RECURRENCE_COUNT"}{$data->{ID}}) if ($hash->{helper}{"RECURRENCE_COUNT"}{$data->{ID}});
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

## sort by wunderlist order
sub wunderlist_sortWunderlist($) {
	my ($hash) = @_;
	
	my $name=$hash->{NAME};
	
	my $lText="";
	

	CommandDeleteReading(undef, "$hash->{NAME} (T|t)ask_.*");
	
	readingsBeginUpdate($hash);
	
	delete($hash->{helper}{"IDS"});
	
	## sort Tasks and write them back
	my $i = 0;
	my @pos = @{$hash->{helper}{"POSITIONS"}};

	
	$i = 0;
	foreach my $ID (@pos) {
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i),$hash->{helper}{"TITLE"}{$ID});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_dueDate",$hash->{helper}{"DUE_DATE"}{$ID}) if ($hash->{helper}{"DUE_DATE"}{$ID});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_assigneeId",$hash->{helper}{"ASSIGNEE_ID"}{$ID}) if ($hash->{helper}{"ASSIGNEE_ID"}{$ID});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_starred",$hash->{helper}{"STARRED"}{$ID}) if ($hash->{helper}{"STARRED"}{$ID});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_recurrenceType",$hash->{helper}{"RECURRENCE_TYPE"}{$ID}) if ($hash->{helper}{"RECURRENCE_TYPE"}{$ID});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_recurrenceCount",$hash->{helper}{"RECURRENCE_COUNT"}{$ID}) if ($hash->{helper}{"RECURRENCE_COUNT"}{$ID});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_completedAt",$hash->{helper}{"COMPLETED_AT"}{$ID}) if ($hash->{helper}{"COMPLETED_AT"}{$ID});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_completedById",$hash->{helper}{"COMPLETED_BY_ID"}{$ID}) if ($hash->{helper}{"COMPLETED_BY_ID"}{$ID});
		readingsBulkUpdate($hash,"Task_".sprintf("%03s",$i)."_ID",$ID);
		
		$hash->{helper}{"IDS"}{"Task_".$i} = $ID;
		$hash->{helper}{"WID"}{$ID} = $i;
		
		if (!$hash->{helper}{"COMPLETED_AT"}{$ID}) {
			$lText.=", " if ($i != 0);
			$lText.=$hash->{helper}{"TITLE"}{$ID};
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
sub wunderlist_clearList($) {
	my ($hash) = @_;
	
	## iterate through all tasks
	foreach my $id (%{$hash->{helper}{IDS}}) {
		my $dHash->{hash}=$hash;
		if ($id !~ /Task_/) {
			$dHash->{id}=$id;
			InternalTimer(gettimeofday()+0.1, "wunderlist_doUpdateTask", $dHash, 0);
		}
	}
}

sub wunderlist_doUpdateTask($) {
	my ($dHash) = @_;
	my $hash = $dHash->{hash};
	my $id = $dHash->{id};
	my $name = $hash->{NAME};
	wunderlist_UpdateTask($hash,"ID:".$id,"delete");
}


sub wunderlist_Undefine($$) {
  my ($hash, $arg) = @_;
	
  RemoveInternalTimer($hash);
	
  return undef;
}

################################################
# If Device is deleted, delete the password data
sub wunderlist_Delete($$)
{
    my ($hash, $name) = @_;  
    
    my $old_index = "wunderlist_".$name."_passwd";
    
    my $old_key =getUniqueId().$old_index;
    
    my ($err, $old_pwd) = getKeyValue($old_index);
    
    return undef unless(defined($old_pwd));
		    
    setKeyValue($old_index, undef);

		
		Log3 $name, 3, "wunderlist: device $name as been deleted. Access-Token has been deleted too.";
}

################################################
# If Device is renamed, copy the password data
sub wunderlist_Rename($$)
{
    my ($new, $old) = @_;  
    
    my $old_index = "wunderlist_".$old."_passwd";
    my $new_index = "wunderlist_".$new."_passwd";
    
    my $old_key =getUniqueId().$old_index;
    my $new_key =getUniqueId().$new_index;
    
    my ($err, $old_pwd) = getKeyValue($old_index);
    
    return undef unless(defined($old_pwd));
    
    setKeyValue($new_index, $old_pwd);
    setKeyValue($old_index, undef);
		
		Log3 $new, 3, "wunderlist: device has been renamed from $old to $new. Access-Token has been assigned to new name.";
}

################################################
# If Device is copied, copy the password data
sub wunderlist_Copy($$)
{
    my ($old, $new) = @_;  
    
    my $old_index = "wunderlist_".$old."_passwd";
    my $new_index = "wunderlist_".$new."_passwd";
    
    my $old_key =getUniqueId().$old_index;
    my $new_key =getUniqueId().$new_index;
    
    my ($err, $old_pwd) = getKeyValue($old_index);
    
    return undef unless(defined($old_pwd));
		    
    setKeyValue($new_index, $old_pwd);
		
		my $new_hash = $defs{$new};
		
		delete($new_hash->{helper}{PWD_NEEDED});
		
		Log3 $new, 3, "wunderlist: device has been copied from $old to $new. Access-Token has been assigned to new device.";
}

sub wunderlist_Attr($@) {
  my ($cmd, $name, $attrName, $attrVal) = @_;
	
  my $orig = $attrVal;
	
	my $hash = $defs{$name};
	
	if ( $attrName eq "disable" ) {

		if ( $cmd eq "set" && $attrVal == 1 ) {
			if ($hash->{READINGS}{state}{VAL} ne "disabled") {
				readingsSingleUpdate($hash,"state","disabled",1);
				RemoveInternalTimer($hash,"wunderlist_GetTasks");
				RemoveInternalTimer($hash);
				Log3 $name, 4, "wunderlist ($name): $name is now disabled";
			}
		}
		elsif ( $cmd eq "del" || $attrVal == 0 ) {
			if ($hash->{READINGS}{state}{VAL} ne "active") {
				readingsSingleUpdate($hash,"state","active",1);
				RemoveInternalTimer($hash,"wunderlist_GetTasks");
				RemoveInternalTimer($hash);
				Log3 $name, 4, "wunderlist ($name): $name is now ensabled";
				InternalTimer(gettimeofday()+1, "wunderlist_GetTasks", $hash, 0);
			}
		}
	}
	
	if ( $attrName eq "pollInterval" ) {
		if ( $cmd eq "set" ) {
			return "$name: pollInterval has to be a number (seconds)" if ($attrVal!~ /\d+/);
			return "$name: pollInterval has to be greater than or equal 600" if ($attrVal < 600);
			$hash->{INTERVAL}=$attrVal;
			Log3 $name, 4, "wunderlist ($name): set new pollInterval to $attrVal";
		}
		elsif ( $cmd eq "del" ) {
			$hash->{INTERVAL}=1800;
			Log3 $name, 4, "wunderlist ($name): set new pollInterval to 1800 (standard)";
		}
		RemoveInternalTimer($hash,"wunderlist_GetTasks");
		InternalTimer(gettimeofday()+1, "wunderlist_GetTasks", $hash, 0) if (!IsDisabled($name) && IsDisabled($name) != 3);
	}
	
	if ( $attrName eq "sortTasks" ) {
		if ( $cmd eq "set" ) {
			return "$name: sortTasks has to be 0 or 1" if ($attrVal !~ /^(0|1|2)$/);
			Log3 $name, 4, "wunderlist ($name): set attribut sortTasks to $attrVal";
		}
		elsif ( $cmd eq "del" ) {
			Log3 $name, 4, "wunderlist ($name): deleted attribut sortTasks (standard)";
		}
		RemoveInternalTimer($hash,"wunderlist_GetTasks");
		InternalTimer(gettimeofday()+1, "wunderlist_GetTasks", $hash, 0) if (!IsDisabled($name) && IsDisabled($name) != 3);
	}
	
	if ( $attrName eq "getCompleted" ) {
		if ( $cmd eq "set" ) {
			return "$name: getCompleted has to be 0 or 1" if ($attrVal !~ /^(0|1)$/);
			Log3 $name, 4, "wunderlist ($name): set attribut getCompleted to $attrVal";
		}
		elsif ( $cmd eq "del" ) {
			Log3 $name, 4, "wunderlist ($name): deleted attribut getCompleted (standard)";
		}
		RemoveInternalTimer($hash,"wunderlist_GetTasks");
		InternalTimer(gettimeofday()+1, "wunderlist_GetTasks", $hash, 0) if (!IsDisabled($name) && IsDisabled($name) != 3);
	}
	
	if ($attrName eq "listDivider") {
		wunderlist_RestartGetTimer($hash);
	}
	
	return;
}

sub wunderlist_Set ($@) {
  my ($hash, $name, $cmd, @args) = @_;
	
	my @sets = ();
	
	push @sets, "active:noArg" if (IsDisabled($name));
	push @sets, "inactive:noArg" if (!IsDisabled($name));
	if (!IsDisabled($name) && !$hash->{helper}{PWD_NEEDED}) {
		push @sets, "addTask";
		push @sets, "completeTask";
		push @sets, "deleteTask";
		push @sets, "updateTask";
		push @sets, "clearList:noArg";
		push @sets, "getTasks:noArg";
	}
	push @sets, "accessToken" if ($hash->{helper}{PWD_NEEDED});
	push @sets, "newAccessToken" if (!$hash->{helper}{PWD_NEEDED});
	push @sets, "sortTasks:noArg" if (!IsDisabled($name) && !$hash->{helper}{PWD_NEEDED} && AttrVal($name,"sortTasks",0) != 1);
	
	return join(" ", @sets) if ($cmd eq "?");
	
	my $usage = "Unknown argument ".$cmd.", choose one of ".join(" ", @sets) if(scalar @sets > 0);
	
	if (IsDisabled($name) && $cmd !~ /^(active|inactive|.*ccessToken)?$/) {
		Log3 $name, 3, "wunderlist ($name): Device is disabled at set Device $cmd";
		return "Device is disabled. Enable it on order to use command ".$cmd;
	}
	
	if ( $cmd =~ /^(active|inactive)?$/ ) {   
		readingsSingleUpdate($hash,"state",$cmd,1);
		RemoveInternalTimer($hash,"wunderlist_GetTasks");
		CommandDeleteAttr(undef,"$name disable") if ($cmd eq "active" && AttrVal($name,"disable",0)!=1);
		InternalTimer(gettimeofday()+1, "wunderlist_GetTasks", $hash, 0) if (!IsDisabled($name) && $cmd eq "active");
		Log3 $name, 3, "wunderlist ($name): set Device $cmd";
	}
	elsif ($cmd eq "getTasks") {
		RemoveInternalTimer($hash,"wunderlist_GetTasks");
		Log3 $name, 4, "wunderlist ($name): set getTasks manually. Timer restartet.";
		InternalTimer(gettimeofday()+1, "wunderlist_GetTasks", $hash, 0) if (!IsDisabled($name) && !$hash->{helper}{PWD_NEEDED});
	}
	elsif ($cmd eq "accessToken" || $cmd eq "newAccessToken") {
		return wunderlist_setPwd ($hash,$name,@args);
	}
	elsif ($cmd eq "addTask" || $cmd eq "newTask") {
		my $count=@args;
		if ($count!=0) {
			my $exp=decode_utf8(join(" ",@args));
			wunderlist_CreateTask ($hash,$exp);
		}
		return "new Task needs a title" if ($count==0);
	}
	elsif ($cmd eq "completeTask") {
		my $count=@args;
		if ($count!=0) {
			my $exp=decode_utf8(join(" ",@args));
			wunderlist_UpdateTask ($hash,$exp,"complete");
		}
		return "in order to complete a task, we need it's ID" if ($count==0);
	}
	elsif ($cmd eq "updateTask") {
		my $count=@args;
		if ($count!=0) {
			my $exp=decode_utf8(join(" ",@args));
			wunderlist_UpdateTask ($hash,$exp,"update");
		}
		return "in order to complete a task, we need it's ID" if ($count==0);
	}
	elsif ($cmd eq "deleteTask") {
		my $count=@args;
		if ($count!=0) {
			my $exp=decode_utf8(join(" ",@args));
			wunderlist_UpdateTask ($hash,$exp,"delete");
		}
		return "in order to delete a task, we need it's ID" if ($count==0);
	}
	elsif ($cmd eq "sortTasks") {
		wunderlist_sort($hash);
	}
	elsif ($cmd eq "clearList") {
		wunderlist_clearList($hash);
	}
	else {
		return $usage;
	}

	return undef;
	
}

sub wunderlist_Get($@) {
  my ($hash, $name, $cmd, @args) = @_;
  my $ret = undef;
  
  if ( $cmd eq "version") {
  	$hash->{VERSION} = $version;
    return "Version: ".$version;
  }
  else {
    $ret ="$name get with unknown argument $cmd, choose one of " . join(" ", sort keys %gets);
  }
 
  return $ret;
}

#####################################
# sets wunderlist Access Token
sub wunderlist_setPwd($$@) {
	my ($hash, $name, @pwd) = @_;
	 
	return "Password can't be empty" if (!@pwd);
	
	
	my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
  my $key = getUniqueId().$index;
	
	Log3 $name,5,"wunderlist ($name): unencoded pwd: $pwd[0]";
	
	my $pwdString=$pwd[0];

	$pwdString=encode_base64($pwdString);
	$pwdString =~ s/^\s+|\s+$//g;
	$pwdString =~ s/\n//g;
	
		 
	my $err = setKeyValue($index, $pwdString);
  
	return "error while saving the password - $err" if(defined($err));
  
	delete($hash->{helper}{PWD_NEEDED}) if(exists($hash->{helper}{PWD_NEEDED}));
	
	
	RemoveInternalTimer($hash,"wunderlist_GetTasks");
	
	if (AttrVal($name,"disable",0) != 1) {
		readingsSingleUpdate($hash,"state","active",1);
		InternalTimer(gettimeofday()+1, "wunderlist_GetTasks", $hash, 0);
	}
	
	Log3 $name, 3, "wunderlist ($name). New Password set.";
	
	return "password successfully saved";
	 
}

#####################################
# reads the Access Token and checks it
sub wunderlist_checkPwd ($$) {
	my ($hash, $pwd) = @_;
	my $name = $hash->{NAME};
    
  my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
  my $key = getUniqueId().$index;
	
	my ($err, $password) = getKeyValue($index);
        
  if ($err) {
		$hash->{helper}{PWD_NEEDED} = 1;
    Log3 $name, 3, "wunderlist ($name): unable to read password from file: $err";
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

sub wunderlist_Notify ($$) {
	my ($hash,$dev) = @_;
	
	my $name = $hash->{NAME};

  return if($dev->{NAME} ne "global");
	
  return if(!grep(m/^INITIALIZED|REREADCFG$/, @{$dev->{CHANGED}}));

  RemoveInternalTimer($hash, "wunderlist_GetTasks");
	InternalTimer(gettimeofday()+1, "wunderlist_GetTasks", $hash, 0) if (!IsDisabled($name) && !$hash->{helper}{PWD_NEEDED});

  return undef;

}

# restart timers for getTasks if active
sub wunderlist_RestartGetTimer($) {
	my ($hash) = @_;
	
	my $name = $hash->{NAME};
	
	RemoveInternalTimer($hash, "wunderlist_GetTasks");
	InternalTimer(gettimeofday()+0.4, "wunderlist_GetTasks", $hash, 0) if (!IsDisabled($name) && !$hash->{helper}{PWD_NEEDED});
	
	return undef;
}

sub wunderlist_Html($;$$) {
	my ($name,$showDueDate) = @_;
	
	$showDueDate=0 if (!defined($showDueDate));
	
	my $hash = $defs{$name};
  my $id   = $defs{$name}{NR};
  
  my $ret="";
  
  # Javascript
  $ret.="<script type=\"text/javascript\" src=\"$FW_ME/pgm2/wunderlist.js\"></script>";
  
  $ret .= "<table class=\"roomoverview\">\n";
  
  $ret .= "<tr><td colspan=\"3\"><div class=\"devType\">".$name."</div></td></tr>";
  $ret .= "<tr><td colspan=\"3\"><table class=\"block wide\" id=\"wunderlist_".$name."_table\">\n"; 
  
  my $i=1;
  my $eo;
  my $cs=3;
  
  if ($showDueDate) {
		$ret .= "<tr>\n".
						" <td class=\"col1\"> </td>\n".
						" <td class=\"col1\">Task</td>\n".
						" <td class=\"col3\">Due date</td>\n";
	}
  
  foreach (@{$hash->{helper}{TIDS}}) {
  	
  	if ($i%2==0) {
  		$eo="even";
  	}
  	else {
  		$eo="odd";
  	}
  	
  	
  	$ret .= "<tr id=\"".$name."_".$_."\" data-data=\"true\" data-line-id=\"".$_."\" class=\"".$eo."\">\n".
  					"	<td class=\"col1\">\n".
  					"		<input class=\"wunderlist_checkbox_".$name."\" type=\"checkbox\" id=\"check_".$_."\" data-id=\"".$_."\" />\n".
  					"	</td>\n".
  					"	<td class=\"col1\">\n".
  							"<span class=\"wunderlist_task_text\" data-id=\"".$_."\">".$hash->{helper}{TITLE}{$_}."</span>\n".
  							"<input type=\"text\" data-id=\"".$_."\" style=\"display:none;\" class=\"wunderlist_input\" value=\"".$hash->{helper}{TITLE}{$_}."\" />\n".
  					"	</td>\n";
  	
  	if ($showDueDate) {
  		$ret .= "<td class=\"col3\">".$hash->{helper}{DUE_DATE}{$_}."</td>\n";
  		$cs=4;
  	}					
  	
  	$ret .= "<td class=\"col2\">\n".
  					" <a href=\"#\" class=\"wunderlist_delete\" data-id=\"".$_."\">\n".
  					"		x\n".
  					" </a>\n".
  					"</td>\n";
  					
    $ret .= "</tr>\n";
    
  	$i++;
  }
  
  $ret .= "<tr class=\"".$eo."\">";
  
  
  $ret .= "<td colspan=\"".$cs."\">".
  				"	<input type=\"hidden\" class=\"wunderlist_name\" id=\"wunderlist_name_".$name."\" value=\"".$name."\" />\n".
  				" <input type=\"text\" id=\"newEntry_".$name."\" />\n".
  				"</td>";
  
  $ret .= "</tr>";
  
  $ret .= "</table></td></tr>\n";
  
  $ret .= "</table>\n";
  
  return $ret;
}

sub wunderlist_AllHtml(;$$$) {
	my ($regEx,$showDueDate) = @_;
	
	$showDueDate=0 if (!defined($showDueDate));
	$regEx="" if (!defined($regEx));
	
	my $filter="";
	
	$filter.=":FILTER=".$regEx;
	
	my @devs = devspec2array("TYPE=wunderlist".$filter);
	my $ret="";
	
	# Javascript
	my $rot .= "<script type=\"text/javascript\" src=\"$FW_ME/www/pgm2/wunderlist.js\"></script>";
	
	my $r=0;
	
	my $count = @devs;
	my $width = 100/$count;
	
	my $style="float:left;margin-right:10px;width:".$width;
	
	foreach my $name (@devs) {
		
		$r++;
	
		my $hash = $defs{$name};
	  my $id   = $defs{$name}{NR};
	  
	  if ($r==$count) {
	  	$style="float:none;";	
	  }	
	    
	  $ret .= "<div style=\"".$style."\"><table class=\"roomoverview\">\n";
	  
	  $ret .= "<tr><td colspan=\"3\"><div class=\"devType\">".$name."</div></td></tr>";
	  $ret .= "<tr><td colspan=\"3\"><table class=\"block wide\" id=\"wunderlist_".$name."_table\">\n"; 
	  
	  my $i=1;
	  my $eo;
	  my $cs=3;
	  
	  if ($showDueDate) {
			$ret .= "<tr>\n".
							" <td class=\"col1\"> </td>\n".
							" <td class=\"col1\">Task</td>\n".
							" <td class=\"col3\">Due date</td>\n";
		}
	  
	  foreach (@{$hash->{helper}{TIDS}}) {
	  	
	  	if ($i%2==0) {
	  		$eo="even";
	  	}
	  	else {
	  		$eo="odd";
	  	}
	  	
	  	
	  	$ret .= "<tr id=\"".$name."_".$_."\" data-data=\"true\" data-line-id=\"".$_."\" class=\"".$eo."\">\n".
	  					"	<td class=\"col1\">\n".
	  					"		<input class=\"wunderlist_checkbox_".$name."\" type=\"checkbox\" id=\"check_".$_."\" data-id=\"".$_."\" />\n".
	  					"	</td>\n".
	  					"	<td class=\"col1\">\n".
	  							"<span class=\"wunderlist_task_text\" data-id=\"".$_."\">".$hash->{helper}{TITLE}{$_}."</span>\n".
	  							"<input type=\"text\" data-id=\"".$_."\" style=\"display:none;\" class=\"wunderlist_input\" value=\"".$hash->{helper}{TITLE}{$_}."\" />\n".
	  					"	</td>\n";
	  	
	  	if ($showDueDate) {
	  		$ret .= "<td class=\"col3\">".$hash->{helper}{DUE_DATE}{$_}."</td>\n";
	  		$cs=4;
	  	}					
	  	
	  	$ret .= "<td class=\"col2\">\n".
	  					" <a href=\"#\" class=\"wunderlist_delete_".$name."\" data-id=\"".$_."\">\n".
	  					"		x\n".
	  					" </a>\n".
	  					"</td>\n";
	  					
	    $ret .= "</tr>\n";
	    
	  	$i++;
	  }
  
	  $ret .= "<tr class=\"".$eo."\">";
	  
	  
	  $ret .= "<td colspan=\"".$cs."\">".
	  				"	<input type=\"hidden\" class=\"wunderlist_name\" id=\"wunderlist_name_".$name."\" value=\"".$name."\" />\n".
	  				" <input type=\"text\" id=\"newEntry_".$name."\" />\n".
	  				"</td>";
	  
	  $ret .= "</tr>";
	  
	  $ret .= "</table></td></tr>\n";
	  
	  $ret .= "</table></div>\n";
	}
  
  return $rot.$ret;
}

sub wunderlist_inArray {
  my ($arr,$search_for) = @_;
  foreach (@$arr) {
  	return 1 if ($_ eq $search_for);
  }
  return 0;
}

1;

=pod
=item summary    uses wunderlist API to add, read, complete and delete tasks in a  wunderlist tasklist
=item summary_DE Taskverwaltung einer wunderlist Taskliste über die wunderlist API
=begin html

<a name="wunderlist"></a>
<h3>wunderlist</h3>
<ul>
  A module to get a task list as readings from wunderlist. Tasks can be completed and deleted.
	<br /><br />
	As preparation to use this module, you need a wunderlist account and you have to register an app as developer. 
	You will need a CLIENT-ID and an ACCESS-TOKEN.
	<br /><br />
	Notes:<br />
	<ul>
		<li>JSON, Data::Dumper and MIME::Base64 have to be installed on the FHEM host.</li>
	</ul>
	<br /><br />
	<a name="wunderlist_Define"></a>
  <b>Define</b><br />
  <ul>
    <code>define &lt;name&gt; wunderlist &lt;CLIENT-ID&gt; &lt;LIST-ID&gt;</code><br />
    <br />
		<b>CLIENT-ID:</b> You can get this ID, if you register an app at wunderlist.<br />
		<b>LIST-ID:</b> This ID can bee taken from the URL of your specified list on the wunderlist web page.<br />
    <br /><br />

    Example:
    <ul>
      <code>define Einkaufsliste wunderlist bed11eer1355f66230b9 257528237</code><br />
    </ul>
  </ul><br />
	<br />
	<a name="wunderlist_Set"></a>
  <b>Set</b>
  <ul>
		<li><b>accessToken</b> - set the access token for your wunderlist app</li><br />
		<li><b>active</b> - set the device active (starts the timer for reading task-list periodically)</li><br />
		<li><b>inactive</b> - set the device inactive (deletes the timer, polling is off)</li><br />
		<li><b>newAccessToken</b> - replace the saved token with a new one.</li><br />
		<li><b>getTasks</b> - get the task list immediately, reset timer.</li><br />
		<li><b>addTask</b> - create a new task. Needs title as parameter.<br /><br />
		<code>set &lt;DEVICE&gt; addTask &lt;TASK_TITLE&gt;[:&lt;DUE_DATE&gt;]</code><br ><br />
		Additional Parameters are:<br />
		<ul>
		 <li>dueDate (due_date)=&lt;DUE_DATE&gt; (formatted as an ISO8601 date)</li>
		 <li>assignee_id=&lt;ASSIGNEE_ID&gt; (integer)</li>
		 <li>recurrence_type=&lt;RECURRENCE_TYPE&gt; (string)</li>
		 <li>recurrence_count=&lt;RECURRENCE_COUNT&gt; (integer - is set to 1 if recurrence_type is given and 
		 recurrence_count is not)</li>
		 <li>starred="true"|"false" (string)</li>
		</ul><br />
		Example: <code>set &lt;DEVICE&gt; addTask &lt;TASK_TITLE&gt; dueDate=2017-01-15 starred=1 
		recurrence_type='week'</code><br /><br />
		<li><b>updateTask</b> - update a task. Needs Task-ID or wunderlist-Task-ID as parameter<br /><br />
		Possible Parameters are:<br />
		<ul>
		 <li>dueDate (due_date)=&lt;DUE_DATE&gt; (formatted as an ISO8601 date)</li>
		 <li>assignee_id=&lt;ASSIGNEE_ID&gt; (integer)</li>
		 <li>recurrence_type=&lt;RECURRENCE_TYPE&gt; (string)</li>
		 <li>recurrence_count=&lt;RECURRENCE_COUNT&gt; (integer - is set to 1 if recurrence_type is given 
		 and recurrence_count is not)</li>
		 <li>starred="true"|"false" (string)</li>
		 <li>completed="true"|"false" (string)</li>
		 <li>title=&lt;TITLE&gt; (string)</li>
		 <li>remove=&lt;TYPE&gt; (comma seperated list of attributes which should be removed from the task)
		</ul><br />
		Examples: <br /><br />
		<code>set &lt;DEVICE&gt; updateTask ID:12345678 dueDate=2017-01-15 starred=1 recurrence_type='week'</code><br />
		<code>set &lt;DEVICE&gt; updateTask 1 dueDate=2017-01-15 starred=1 recurrence_type='week'</code><br />
		<code>set &lt;DEVICE&gt; updateTask 2 remove=due_date,starred</code><br />
		
		<br /><br />
		<li><b>completeTask</b> - completes a task. Needs number of task (reading 'Task_NUMBER') or the 
		wunderlist-Task-ID (ID:<ID>) as parameter</li><br />
		<code>set &lt;DEVICE&gt; completeTask &lt;TASK-ID&gt;</code> - completes a task by number<br >
		<code>set &lt;DEVICE&gt; completeTask ID:&lt;wunderlist-TASK-ID&gt;</code> - completes a task by wunderlist-Task-ID<br ><br />
		<li><b>deleteTask</b> - deletes a task. Needs number of task (reading 'Task_NUMBER') or the wunderlist-Task-ID (ID:<ID>) as parameter</li><br />
		<code>set &lt;DEVICE&gt; deleteTask &lt;TASK-ID&gt;</code> - deletes a task by number<br >
		<code>set &lt;DEVICE&gt; deleteTask ID:&lt;wunderlist-TASK-ID&gt;</code> - deletes a task by wunderlist-Task-ID<br ><br />
		<li><b>sortTasks</b> - sort Tasks alphabetically<br /><br />
		<li><b>clearList</b> - <b><u>deletes</u></b> all Tasks from the list (only FHEM listed Tasks can be deleted)
	</ul>
	<br />
	<a name="wunderlist_Attributes"></a>
  <b>Attributes</b><br />
  <ul>
		<li><a href="#readingFnAttributes">readingFnAttributes</a></li><br />
		<li><a href="#do_not_notify">do_not_notify</a></li><br />
    <li><a name="#disable">disable</a></li><br />
		<li>pollInterval</li>
		get the list every pollInterval seconds. Default is 1800. Smallest possible value is 600.<br /><br />
		<li>sortTasks</li>
		<ul>
		<li>0: don't sort the tasks</li>
		<li>1: sorts Tasks alphabetically after every update</li>
		<li>2: sorts Tasks in wunderlist order</li>
		</ul>
		<br /><br />
		<li>getCompleted</li>
		get's completed Tasks from list additionally. 
	</ul><br />
	
	<a name="wunderlist_Readings"></a>
  <b>Readings</b><br />
  <ul>
		<li>Task_XXX<br />
      the tasks are listet as Task_000, Task_001 [...].</li><br />
		<li>Task_XXX_dueDate<br />
      if a task has a due date, this reading should be filled with the date.</li><br />
		<li>Task_XXX_ID<br />
      the wunderlist ID of Task_X.</li><br />
		<li>Task_XXX_starred<br />
      if a task is starred, this reading should be filled with the 1.</li><br />
		<li>Task_XXX_assigneeId<br />
      if a task has an assignee, this reading should be filled with the the corresponding ID.</li><br />
		<li>Task_XXX_recurrenceType<br />
      if a task has recurrence_type as attribute, this reading should be filled with the type.</li><br />
		<li>Task_XXX_recurrenceCount<br />
      if a task has recurrence_type as attribute, this reading should be filled with the count.</li><br />
		<li>Task_XXX_completedAt<br />
      only for completed Tasks (attribute getCompleted).</li><br />
		<li>Task_XXX_completedById<br />
      only for completed Tasks (attribute getCompleted).</li><br />
		<li>User_XXX<br />
      the lists users are listet as User_000, User_001 [...].</li><br />
		<li>User_XXX_ID<br />
      the users wunderlist ID.</li><br />
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
			state of the wunderlist-Device</li>
  </ul><br />
  <a name="wunderlist_Weblink"></a>
  <h4>Weblink</h4>
  <ul>
		Defines a simple weblink for a Task list.
		<br /><br />
		<code>define &lt;NAME&gt; weblink htmlCode {wunderlist_Html("&lt;WUNDERLIST-DEVCICENAME&gt;")}</code>
	</ul>
	<br /><br />
	<ul>
		Define a simple weblink for all Task lists.
		<br /><br />
		<code>define &lt;NAME&gt; weblink htmlCode {wunderlist_AllHtml()}</code>
		<code>define &lt;NAME&gt; weblink htmlCode {wunderlist_AllHtml('<REGEX-FILTER>')}</code>
	</ul>
</ul>

=end html
=cut