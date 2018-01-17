var req = new XMLHttpRequest();
req.open('GET', document.location, false);
req.send(null);
var csrfToken = req.getResponseHeader('X-FHEM-csrfToken');

function encodeParm(oldval) {
    var newval;
    newval = oldval.replace(/\$/g, '\\%24');
    newval = newval.replace(/"/g, '%27');
    newval = newval.replace(/#/g, '%23');
    newval = newval.replace(/\+/g, '%2B');
    newval = newval.replace(/&/g, '%26');
    newval = newval.replace(/'/g, '%27');
    newval = newval.replace(/=/g, '%3D');
    newval = newval.replace(/\?/g, '%3F');
    newval = newval.replace(/\|/g, '%7C');
    newval = newval.replace(/\s/g, '%20');
    return newval;
};

function dialog(message) {
    $('<div></div>').appendTo('body').html('<div>' + message + '</div>').dialog({
        modal: true, title: 'Todoist Error', zIndex: 10000, autoOpen: true,
        width: 'auto', resizable: false,
        buttons: {
            OK: function () {
                $(this).dialog("close");
            }
        },
        close: function (event, ui) {
            $(this).remove();
        }
    });
};

function sendCommand(cmd) {
	var location = document.location.pathname;
  if (location.substr(location.length -1, 1) == '/') {
      location = location.substr(0, location.length -1);
  }
  var url = document.location.protocol + "//" + document.location.host + location;
  FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + '=' + cmd);
}


function todoist_check(title,name,id) {
	var location = document.location.pathname;
  if (location.substr(location.length -1, 1) == '/') {
      location = location.substr(0, location.length -1);
  }
  sendCommand('set ' + name + ' completeTask ID:'+ id);
}

function todoist_ErrorDialog($text) {
	dialog($text);
}

function removeLine(name,id) {
	var i=1;
	$('table#todoist_' + name + '_table').find('tr').each(function() {
		var tid = $(this).attr("data-line-id");
		if (tid==id) $(this).remove();
		else {
			$(this).removeClass("odd even");
			if (i%2==0) $(this).addClass("even");
			else $(this).addClass("odd");
			i++;
		}
	});
}

function addLine(name,id,title) {
	var lastEl=$('table#todoist_' + name + '_table').find('tr').last().prev();
	var cl = $(lastEl).attr('class');
	if (cl=="even") cl="odd";
	else cl="even"
	$(lastEl).after('<tr id="'+ name + "_" + id +'" data-line-id="' + id +'" class="' + cl +'">\n' +
  					'	<td class="col1"><input onclick="todoist_check(\'' + title + '\',\'' + name + '\',\'' + id + '\')" type="checkbox" id="check_' + id + '" data-id="' + id + '" /></td>\n' +
  					'	<td class="col1">' + title + '</td>\n' +
           	'</tr>\n'
  );
}

$(document).ready(function(){
	var name = $('#todoist_name').val();
	$('#newEntry_' + name).on('blur keypress',function(e) {
		if (e.type!='keypress' || e.which==13) {
			e.preventDefault()
			var v=encodeParm($(this).val());
			if (v!="") {
				sendCommand('set '+ name +' addTask ' + v);
				$(this).val("");
			}
		}
	});
	$('#todoist_' + name + '_table input[type="checkbox"]').on('click',function(e) {
		var val=$(this).attr('checked');
		if (!val) {
			var id=$(this).attr('data-id');
			sendCommand('set ' + name + ' completeTask ID:'+ id);
		}
	});
});