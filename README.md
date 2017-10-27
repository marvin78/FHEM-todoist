# FHEM-todoist
Manage your todoist Tasklists in FHEM

A module to get a task list as readings from todoist. Tasks can be completed, updated and deleted. 

As preparation to use this module, you need to get your API Symbol (API ID) from the preferences of your account. 

Notes:
JSON, Data::Dumper, MIME::Base64, Date::Parse and Data::UUID have to be installed on the FHEM host.


Define
define <name> todoist <PROJECT-ID>

PROJECT-ID: The ID of your project (=list).


Example:
define Einkaufsliste todoist 257528237


Set
accessToken - set the API Symbol for your todoist app

active - set the device active (starts the timer for reading task-list periodically)

inactive - set the device inactive (deletes the timer, polling is off)

newAccessToken - replace the saved token with a new one.

getTasks - get the task list immediately, reset timer.

addTask - create a new task. Needs title as parameter.

set <DEVICE> addTask <TASK_TITLE>[:<DUE_DATE>]

Additional Parameters are:
dueDate (due_date)=<DUE_DATE> (can be free form text or format: YYYY-MM-DDTHH:MM)
priority=the priority of the task (a number between 1 and 4, 4 for very urgent and 1 for natural).

Examples: 

set <DEVICE> addTask <TASK_TITLE> dueDate=2017-01-15 priority=2

set <DEVICE> addTask <TASK_TITLE> dueDate=morgen

updateTask - update a task. Needs Task-ID or todoist-Task-ID as parameter

Possible additional parameters are:
dueDate (due_date)=<DUE_DATE> (can be free form text or format: YYYY-MM-DDTHH:MM)
priority=(1..4) (string)
title=<TITLE> (string)

Examples: 

set <DEVICE> updateTask ID:12345678 dueDate=2017-01-15 priority=1
set <DEVICE> updateTask 1 dueDate=übermorgen


completeTask - completes a task. Needs number of task (reading 'Task_NUMBER') or the todoist-Task-ID (ID:) as parameter

set <DEVICE> completeTask <TASK-ID> - completes a task by number
set <DEVICE> completeTask ID:<todoist-TASK-ID> - completes a task by todoist-Task-ID

deleteTask - deletes a task. Needs number of task (reading 'Task_NUMBER') or the todoist-Task-ID (ID:) as parameter

set <DEVICE> deleteTask <TASK-ID> - deletes a task by number
set <DEVICE> deleteTask ID:<todoist-TASK-ID> - deletes a task by todoist-Task-ID

sortTasks - sort Tasks alphabetically

clearList - deletes all Tasks from the list (only FHEM listed Tasks can be deleted)

Attributes
readingFnAttributes

do_not_notify

disable

pollInterval
get the list every pollInterval seconds. Default is 1800. Smallest possible value is 600.

sortTasks
0: don't sort the tasks
1: sorts Tasks alphabetically after every update



Readings
Task_XXX
the tasks are listet as Task_000, Task_001 [...].

Task_XXX_dueDate
if a task has a due date, this reading should be filled with the date.

Task_XXX_priority
the priority of your task.

Task_XXX_ID
the todoist ID of Task_X.

listText
a comma seperated list of tasks in the specified list. This may be used for TTS, Messages etc.

count
number of Tasks in list.

error
current error. Default is none.

lastCompletedTask
title of the last completed task.

lastCreatedTask
title of the last created task.

lastDeletedTask
title of the last deleted task.

lastError
last Error.

state
state of the todoist-Device
