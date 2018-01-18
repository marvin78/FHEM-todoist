if (typeof todoist_checkVar === 'undefined') {
	
	var todoist_checkVar=1;

	var req = new XMLHttpRequest();
	req.open('GET', document.location, false);
	req.send(null);
	var csrfToken = req.getResponseHeader('X-FHEM-csrfToken');

	function todoist_encodeParm(oldVal) {
	    var newVal;
	    newVal = oldVal.replace(/\$/g, '\\%24');
	    newVal = newVal.replace(/"/g, '%27');
	    newVal = newVal.replace(/#/g, '%23');
	    newVal = newVal.replace(/\+/g, '%2B');
	    newVal = newVal.replace(/&/g, '%26');
	    newVal = newVal.replace(/'/g, '%27');
	    newVal = newVal.replace(/=/g, '%3D');
	    newVal = newVal.replace(/\?/g, '%3F');
	    newVal = newVal.replace(/\|/g, '%7C');
	    newVal = newVal.replace(/\s/g, '%20');
	    return newVal;
	};

	function todoist_dialog(message) {
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
	    setTimeout(function(){
				$('.ui-dialog').remove();
			},10000);
	};

	function todoist_sendCommand(cmd) {
		var location = document.location.pathname;
	  if (location.substr(location.length -1, 1) == '/') {
	      location = location.substr(0, location.length -1);
	  }
	  var url = document.location.protocol + "//" + document.location.host + location;
	  FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + '=' + cmd);
	}



	function todoist_ErrorDialog($text) {
		todoist_dialog($text);
	}

	function todoist_removeLine(name,id) {
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

	function todoist_addLine(name,id,title) {
		var lastEl=$('table#todoist_' + name + '_table').find('tr').last().prev();
		var cl = $(lastEl).attr('class');
		if (cl=="even") cl="odd";
		else cl="even"
		$(lastEl).after('<tr id="'+ name + "_" + id +'" data-data="true" data-line-id="' + id +'" class="' + cl +'">\n' +
	  					'	<td class="col1"><input class="todoist_checkbox_' + name + '" type="checkbox" id="check_' + id + '" data-id="' + id + '" /></td>\n' +
	  					'	<td class="col1">\n'+
	  					' 	<span class="todoist_task_text" data-id="' + id + '">' + title + '</span>\n'+
	  					'   <input type="text" data-id="' + id + '" style="display:none;" class="todoist_input" value="' + title + '" />'+
	  					' </td>\n' +
	  					' <td class="col2">\n' +
	  					' 	<a href="#" class="todoist_delete_' + name + '" data-id="' + id +'">\n'+
	  					'			x\n'+
	  					' 	</a>\n'+
	  					'	</td>\n'+
	           	'</tr>\n'
	  );
	}

	$(document).ready(function(){
		$('.todoist_name').each(function() {
			var name = $(this).val();
			$('#newEntry_' + name).on('blur keypress',function(e) {
				if (e.type!='keypress' || e.which==13) {
					e.preventDefault();
					var v=todoist_encodeParm($(this).val());
					if (v!="") {
						todoist_sendCommand('set '+ name +' addTask ' + v);
						$(this).val("");
					}
				}
			});
			$('#todoist_' + name + '_table').on('click','input[type="checkbox"]',function(e) {
				var val=$(this).attr('checked');
				if (!val) {
					var id=$(this).attr('data-id');
					todoist_sendCommand('set ' + name + ' closeTask ID:'+ id);
				}
			});
			$('#todoist_' + name + '_table').on('click','a.todoist_delete_'+name,function(e) {
				if (confirm('Are you sure?')) {
					var id=$(this).attr('data-id');
					todoist_sendCommand('set ' + name + ' deleteTask ID:'+ id);
				}
				return false;
			});
			$('#todoist_' + name + '_table').on('click','span.todoist_task_text',function(e) {
				var id = $(this).attr("data-id");
				var val=$(this).html();
				$(this).hide();
				$("input[data-id='" + id +"']").val(val);
				$("input[data-id='" + id +"']").show();
				$("input[data-id='" + id +"']").focus();
			});
			$('#todoist_' + name + '_table').on('blur keypress','input.todoist_input',function(e) {
				if (e.type!='keypress' || e.which==13) {
					e.preventDefault();
					var comp = $(this).prev().html();
					var id = $(this).attr("data-id");
					var val = $(this).val();
					$(this).hide();
					$("span.todoist_task_text[data-id='" + id +"']").show();
					if (val != "" && comp!=val) {
						$("span.todoist_task_text[data-id='" + id +"']").html(val);
						todoist_sendCommand('set ' + name + ' updateTask ID:'+ id + ' title="' + val + '"');
					}
				}
			});
		});
	});
}