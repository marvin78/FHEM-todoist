if (typeof wunderlist_checkVar === 'undefined') {
	
	var wunderlist_checkVar=1;
	var req = new XMLHttpRequest();
	req.open('GET', document.location, false);
	req.send(null);
	var csrfToken = req.getResponseHeader('X-FHEM-csrfToken');

	function wunderlist_encodeParm(oldVal) {
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

	function wunderlist_dialog(message) {
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

	function wunderlist_sendCommand(cmd) {
		var location = document.location.pathname;
	  if (location.substr(location.length -1, 1) == '/') {
	      location = location.substr(0, location.length -1);
	  }
	  var url = document.location.protocol + "//" + document.location.host + location;
	  FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + '=' + cmd);
	}



	function wunderlist_ErrorDialog($text) {
		wunderlist_dialog($text);
	}

	function wunderlist_removeLine(name,id) {
		var i=1;
		$('table#wunderlist_' + name + '_table').find('tr').each(function() {
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

	function wunderlist_addLine(name,id,title) {
		var lastEl=$('table#wunderlist_' + name + '_table').find('tr').last();
		var prevEl=$(lastEl).prev('tr');
		var cl="odd";
		if (prevEl != 'undefined') {
			cl = $(prevEl).attr('class');
			if (cl=="odd") cl="even";
			else cl="odd"
		}
		$(lastEl).before('<tr id="'+ name + "_" + id +'" data-data="true" data-line-id="' + id +'" class="' + cl +'">\n' +
	  					'	<td class="col1"><input class="wunderlist_checkbox_' + name + '" type="checkbox" id="check_' + id + '" data-id="' + id + '" /></td>\n' +
	  					'	<td class="col1">\n'+
	  					' 	<span class="wunderlist_task_text" data-id="' + id + '">' + title + '</span>\n'+
	  					'   <input type="text" data-id="' + id + '" style="display:none;" class="wunderlist_input" value="' + title + '" />'+
	  					' </td>\n' +
	  					' <td class="col2">\n' +
	  					' 	<a href="#" class="wunderlist_delete" data-id="' + id +'">\n'+
	  					'			x\n'+
	  					' 	</a>\n'+
	  					'	</td>\n'+
	           	'</tr>\n'
	  );
	}

	$(document).ready(function(){
		$('.wunderlist_name').each(function() {
			var name = $(this).val();
			$('#newEntry_' + name).on('blur keypress',function(e) {
				if (e.type!='keypress' || e.which==13) {
					e.preventDefault();
					var v=wunderlist_encodeParm($(this).val());
					if (v!="") {
						wunderlist_sendCommand('set '+ name +' addTask ' + v);
						$(this).val("");
					}
				}
			});
			$('#wunderlist_' + name + '_table').on('click','input[type="checkbox"]',function(e) {
				var val=$(this).attr('checked');
				if (!val) {
					var id=$(this).attr('data-id');
					wunderlist_sendCommand('set ' + name + ' completeTask ID:'+ id);
				}
			});
			$('#wunderlist_' + name + '_table').on('click','a.wunderlist_delete',function(e) {
				if (confirm('Are you sure?')) {
					var id=$(this).attr('data-id');
					wunderlist_sendCommand('set ' + name + ' deleteTask ID:'+ id);
				}
				return false;
			});
			$('#wunderlist_' + name + '_table').on('click','span.wunderlist_task_text',function(e) {
				var id = $(this).attr("data-id");
				var val=$(this).html();
				$(this).hide();
				$("input[data-id='" + id +"']").val(val);
				$("input[data-id='" + id +"']").show();
				$("input[data-id='" + id +"']").focus();
			});
			$('#wunderlist_' + name + '_table').on('blur keypress','input.wunderlist_input',function(e) {
				if (e.type!='keypress' || e.which==13) {
					e.preventDefault();
					var comp = $(this).prev().html();
					var id = $(this).attr("data-id");
					var val = $(this).val();
					
					$(this).hide();
					$("span.wunderlist_task_text[data-id='" + id +"']").show();
					if (val != "" && comp!=val) {
						$("span.wunderlist_task_text[data-id='" + id +"']").html(val);
						wunderlist_sendCommand('set ' + name + ' updateTask ID:'+ id + ' title="' + val + '"');
					}
				}
			});
		});
	});
}