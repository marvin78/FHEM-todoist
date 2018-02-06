if (typeof todoist_checkVar === 'undefined') {
	
	var todoist_checkVar=1;

	var req = new XMLHttpRequest();
	req.open('GET', document.location, false);
	req.send(null);
	var csrfToken = req.getResponseHeader('X-FHEM-csrfToken');
	
	var todoist_icon={};
	
	var todoist_svgPrefix='<svg viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg"><path ';
	
	todoist_icon.ref=todoist_svgPrefix+'d="M440.935 12.574l3.966 82.766C399.416 41.904 331.674 8 256 8 134.813 8 33.933 94.924 12.296 209.824 10.908 217.193 16.604 224 24.103 224h49.084c5.57 0 10.377-3.842 11.676-9.259C103.407 137.408 172.931 80 256 80c60.893 0 114.512 30.856 146.104 77.801l-101.53-4.865c-6.845-.328-12.574 5.133-12.574 11.986v47.411c0 6.627 5.373 12 12 12h200.333c6.627 0 12-5.373 12-12V12c0-6.627-5.373-12-12-12h-47.411c-6.853 0-12.315 5.729-11.987 12.574zM256 432c-60.895 0-114.517-30.858-146.109-77.805l101.868 4.871c6.845.327 12.573-5.134 12.573-11.986v-47.412c0-6.627-5.373-12-12-12H12c-6.627 0-12 5.373-12 12V500c0 6.627 5.373 12 12 12h47.385c6.863 0 12.328-5.745 11.985-12.599l-4.129-82.575C112.725 470.166 180.405 504 256 504c121.187 0 222.067-86.924 243.704-201.824 1.388-7.369-4.308-14.176-11.807-14.176h-49.084c-5.57 0-10.377 3.842-11.676 9.259C408.593 374.592 339.069 432 256 432z"/></svg>';
	todoist_icon.del=todoist_svgPrefix+'d="M0 84V56c0-13.3 10.7-24 24-24h112l9.4-18.7c4-8.2 12.3-13.3 21.4-13.3h114.3c9.1 0 17.4 5.1 21.5 13.3L312 32h112c13.3 0 24 10.7 24 24v28c0 6.6-5.4 12-12 12H12C5.4 96 0 90.6 0 84zm416 56v324c0 26.5-21.5 48-48 48H80c-26.5 0-48-21.5-48-48V140c0-6.6 5.4-12 12-12h360c6.6 0 12 5.4 12 12zm-272 68c0-8.8-7.2-16-16-16s-16 7.2-16 16v224c0 8.8 7.2 16 16 16s16-7.2 16-16V208zm96 0c0-8.8-7.2-16-16-16s-16 7.2-16 16v224c0 8.8 7.2 16 16 16s16-7.2 16-16V208zm96 0c0-8.8-7.2-16-16-16s-16 7.2-16 16v224c0 8.8 7.2 16 16 16s16-7.2 16-16V208z"/></svg>';
	todoist_icon.loading='<svg xmlns:svg="http://www.w3.org/2000/svg" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" version="1.0" viewBox="0 0 128 128" xml:space="preserve"><g transform="rotate(135 64 64)"><circle cx="16" cy="64" r="16" fill="#ff9900" fill-opacity="1"/><circle cx="16" cy="64" r="16" fill="#ffbb55" fill-opacity="0.67" transform="rotate(45,64,64)"/><circle cx="16" cy="64" r="16" fill="#ffd494" fill-opacity="0.42" transform="rotate(90,64,64)"/><circle cx="16" cy="64" r="16" fill="#ffebcc" fill-opacity="0.2" transform="rotate(135,64,64)"/><circle cx="16" cy="64" r="16" fill="#fff3e1" fill-opacity="0.12" transform="rotate(180,64,64)"/><circle cx="16" cy="64" r="16" fill="#fff3e1" fill-opacity="0.12" transform="rotate(225,64,64)"/><circle cx="16" cy="64" r="16" fill="#fff3e1" fill-opacity="0.12" transform="rotate(270,64,64)"/><circle cx="16" cy="64" r="16" fill="#fff3e1" fill-opacity="0.12" transform="rotate(315,64,64)"/><animateTransform attributeName="transform" type="rotate" values="0 64 64;315 64 64;270 64 64;225 64 64;180 64 64;135 64 64;90 64 64;45 64 64" calcMode="discrete" dur="1120ms" repeatCount="indefinite"/></g></svg>';

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
	
	function todoist_refreshTable(name,sortit) {
		var i=1;
		$('table#todoist_' + name + '_table').find('tr.todoist_data').each(function() {
			// order
			var tid = $(this).attr("data-line-id");
			$(this).removeClass("odd even");
			if (i%2==0) $(this).addClass("even");
			else $(this).addClass("odd");
			if (typeof sortit != 'undefined') todoist_sendCommand('set ' + name + ' updateTask ID:'+ tid + ' order="' + i + '"');
			i++;
		});
		refreshInput(name);
		refreshInputs(name);
		todoist_removeLoading(name);
	}
	
	function todoist_reloadTable(name,val) {
		$('table#todoist_' + name + '_table').find('tr.todoist_data').remove();
		$('table#todoist_' + name + '_table').find('#newEntry_'+name).parent().parent().before(val);
		todoist_refreshTable(name);
		$('#newEntry_' + name).focus();
	}
	
	function refreshInputs(name) {
		$('table#todoist_' + name + '_table').find('tr.todoist_data').find('td.todoist_input').find('input[type=text]').each(function() {
			var w = $(this).prev('span').width()+5;
			$(this).width(w); 
		});
	}
	
	function refreshInput(name) {
		$('#newEntry_'+name).width(0);
		var w = $('#newEntry_'+name).parent('td').width()-4;
		$('#newEntry_'+name).width(w); 
	}

	function todoist_sendCommand(cmd) {
		var name = cmd.split(" ")[1];
		todoist_addLoading(name);
		var location = document.location.pathname;
	  if (location.substr(location.length -1, 1) == '/') {
	      location = location.substr(0, location.length -1);
	  }
	  var url = document.location.protocol + "//" + document.location.host + location;
	  FW_cmd(url + '?XHR=1&fwcsrf=' + csrfToken + '&cmd.' + name + '=' + cmd);
	}
	
	function todoist_addLoading(name) {
		$('.todoist_devType_' + name).find('.todoist_loadingDiv').remove();
		$('.todoist_devType_' + name).append('<div class="todoist_icon todoist_loadingDiv">' + todoist_icon.loading + '</div>');
	}
	
	function todoist_removeLoading(name) {
		$('.todoist_devType_' + name).find('.todoist_loadingDiv').remove();
	}

	function todoist_ErrorDialog($text) {
		todoist_dialog($text);
	}

	function todoist_removeLine(name,id) {
		var i=1;
		$('table#todoist_' + name + '_table').find('tr.todoist_data').each(function() {
			var tid = $(this).attr("data-line-id");
			if (tid==id) $(this).remove();
			else {
				$(this).removeClass("odd even");
				if (i%2==0) $(this).addClass("even");
				else $(this).addClass("odd");
				i++;
			}
		});
		if (i==1) $('table#todoist_' + name + '_table').find("tr.todoist_ph").show();
		todoist_refreshTable(name);
		todoist_getSizes();
	}

	function todoist_addLine(name,id,title) {
		var lastEl=$('table#todoist_' + name + '_table').find('tr').last();
		var prevEl=$(lastEl).prev('tr');
		var cl="odd";
		if (prevEl != 'undefined') {
			cl = $(prevEl).attr('class');
			if (cl=="odd") cl="even";
			else cl="odd"
		}
		$(lastEl).before('<tr id="'+ name + "_" + id +'" data-data="true" data-line-id="' + id +'" class="sortit todoist_data ' + cl +'">\n' +
	  					'	<td class="col1  todoist_col1">\n'+
	  					'   <div class=\"todoist_move\"></div>\n'+
	  					'		<input class="todoist_checkbox_' + name + '" type="checkbox" id="check_' + id + '" data-id="' + id + '" />\n'+
	  					' </td>\n' +
	  					'	<td class="col1 todoist_input">\n'+
	  					' 	<span class="todoist_task_text" data-id="' + id + '">' + title + '</span>\n'+
	  					'   <input type="text" data-id="' + id + '" style="display:none;" class="todoist_input_' + name +'" value="' + title + '" />'+
	  					' </td>\n' +
	  					' <td class="col2 todoist_delete">\n' +
	  					' 	<a href="#" class="todoist_delete_' + name + '" data-id="' + id +'">\n'+
	  					'			x\n'+
	  					' 	</a>\n'+
	  					'	</td>\n'+
	           	'</tr>\n'
	  );
	  $('table#todoist_' + name + '_table').find("tr.todoist_ph").hide();
	  todoist_getSizes();
	  todoist_refreshTable(name);
	}
	
	function resizable (el, factor) {
	  var int = Number(factor) || 7.7;
	  function resize() {el.style.width = ((el.value.length+1) * int) + 'px'}
	  var e = 'keyup,keypress,focus,blur,change'.split(',');
	  for (var i in e) el.addEventListener(e[i],resize,false);
	  resize();
	}

	
	function todoist_getSizes() {
		var height = 0;
		var width = 0;
		$('.sortable .sortit').each(function() {
			var tHeight = $(this).outerHeight();
			if (tHeight > height) height = tHeight;
		});
		$('.sortable').css('max-height',height).css('height',height);
	}
	
	function todoist_addHeaders() {
		$("<div class='todoist_refresh todoist_icon'> </div>").appendTo($('.todoist_devType')).html(todoist_icon.ref);
		$("<div class='todoist_deleteAll todoist_icon'> </div>").appendTo($('.todoist_devType')).html(todoist_icon.del);
	}

	$(document).ready(function(){
		todoist_getSizes();
		todoist_addHeaders();
		$('.todoist_name').each(function() {
			var name = $(this).val();
			todoist_refreshTable(name);
			
			$('.todoist_devType_' + name).on('click','div.todoist_deleteAll',function(e) {
				if (confirm('Are you sure? This deletes ALL the task in this list permanently.')) {
					todoist_sendCommand('set ' + name + ' clearList');
				}
			});
			$('.todoist_devType_' + name).on('click','div.todoist_refresh',function(e) {
				todoist_sendCommand('set ' + name + ' getTasks');
			});
			
			$('#todoist_' + name + '_table').on('mouseover','.sortit',function(e) {
				$(this).find('div.todoist_move').addClass('todoist_sortit_handler');
			});
			$('#todoist_' + name + '_table').on('mouseout','.sortit',function(e) {
				$(this).find('div.todoist_move').removeClass('todoist_sortit_handler');
			});
			$('#todoist_' + name + '_table').on('blur keypress','#newEntry_' + name,function(e) {
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
				if (confirm('Are you sure? This deletes the task permanently.')) {
					var id=$(this).attr('data-id');
					todoist_sendCommand('set ' + name + ' deleteTask ID:'+ id);
				}
				return false;
			});
			$('#todoist_' + name + '_table').on('click','span.todoist_task_text',function(e) {
				var id = $(this).attr("data-id");
				var val=$(this).html();
				var width=$(this).width()+20;
				$(this).hide();
				$("input[data-id='" + id +"']").show().focus().val("").val(val);
			});
			$('#todoist_' + name + '_table').on('blur keypress','input.todoist_input_'+name,function(e) {
				if (e.type!='keypress' || e.which==13) {
					e.preventDefault();
					var val = $(this).val();
					
					var comp = $(this).prev().html();
					var id = $(this).attr("data-id");
					var val = $(this).val();
					$(this).hide();
					$("span.todoist_task_text[data-id='" + id +"']").show();
					if (val != "" && comp != val) {
						$("span.todoist_task_text[data-id='" + id +"']").html(val);
						todoist_sendCommand('set ' + name + ' updateTask ID:'+ id + ' title="' + val + '"');
					}
					
					if (val == "" && e.which==13) {
						if (confirm('Are you sure?')) {
							$('#newEntry_' + name).focus();
							todoist_sendCommand('set ' + name + ' deleteTask ID:'+ id);
						}
					}
					todoist_refreshTable(name);
				}
				if (e.type=='keypress') {
					resizable(this,7);
					refreshInput(name);
				}
			});
		});
		var fixHelper = function(e, ui) {  
		  ui.children().each(function() {  
		  console.log(e);
		    $(this).width($(this).width());  
		  });  
		  return ui;  
		};
		$( ".todoist_table table.sortable" ).sortable({
			//axis: 'y',
			revert: true,
			items: "> tbody > tr.sortit",
			handle: ".todoist_sortit_handler",
			forceHelperSize: true,
			placeholder: "sortable-placeholder",
			connectWith: '.todoist_table table.sortable',
			helper: fixHelper,
			start: function( event, ui ) { 
				var width = ui.item.innerWidth();
				var height = ui.item.innerHeight();
				ui.placeholder.css("width",width).css("height",height); 
			},
			stop: function (event,ui) {
				var parent = ui.item.parent().parent();
				var id = $(parent).attr('id');
				var name = id.split("_")[1];
				if (ui.item.attr('data-remove')==1) ui.item.remove();
				todoist_refreshTable(name,1);
			},
			remove: function (event,ui) {
				var id=ui.item.attr('data-line-id');
				var tid = ui.item.attr('id');
				var nameH = tid.split("_")[0];
				todoist_sendCommand('set ' + nameH + ' deleteTask ID:'+ id);
			},
			receive: function (event,ui) {
				var parent = ui.item.parent().parent();
				var id = ui.item.attr('data-line-id');
				var tid = parent.attr('id');
				var nameR = tid.split("_")[1];
				var value = ui.item.find('span').html();
				todoist_sendCommand('set '+ nameR +' addTask ' + value);
				ui.item.attr('data-remove','1');
			}
		}).disableSelection();
	});
}