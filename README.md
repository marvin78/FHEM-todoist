# FHEM-todoist
Manage your todoist Tasklists in FHEM

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
    <code>define &lt;name&gt; todoist &lt;PROJECT-ID&gt;</code><br />
    <br />
		<b>PROJECT-ID:</b> The ID of your project (=list).<br />
    <br /><br />

    Example:
      <code>define Einkaufsliste todoist 257528237</code><br />
<br />
	<br />
	<a name="todoist_Set"></a>
  <b>Set</b>
  <ul>
		<li><b>accessToken</b> - set the API Symbol for your todoist app</li><br />
		<li><b>active</b> - set the device active (starts the timer for reading task-list periodically)</li><br />
		<li><b>inactive</b> - set the device inactive (deletes the timer, polling is off)</li><br />
		<li><b>newAccessToken</b> - replace the saved token with a new one.</li><br />
		<li><b>getTasks</b> - get the task list immediately, reset timer.</li><br />
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
		get the list every pollInterval seconds. Default is 1800. Smallest possible value is 600.<br /><br />
		<li>sortTasks</li>
		<ul>
		<li>0: don't sort the tasks</li>
		<li>1: sorts Tasks alphabetically after every update</li>
		<!--<li>2: sorts Tasks in todoist order</li>-->
		</ul>
		<br /><br />
		<!--<li>getCompleted</li>
		get's completed Tasks from list additionally.-->
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
		<!--<li>Task_XXX_completedAt<br />
      only for completed Tasks (attribute getCompleted).</li><br />
		<li>Task_XXX_completedById<br />
      only for completed Tasks (attribute getCompleted).</li><br />
		<li>User_XXX<br />
      the lists users are listet as User_000, User_001 [...].</li><br />
		<li>User_XXX_ID<br />
      the users todoist ID.</li><br />-->
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
