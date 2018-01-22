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
	
	function todoist_refreshTable(name,sortit) {
		var i=1;
		$('table#todoist_' + name + '_table').find('tr').each(function() {
			// sizes of inputs
			var input = $(this).find('td.todoist_input').find('input[type=text]');
			var sizeVal = $(this).find('td.todoist_input').find('span.todoist_task_text').width();
			var size = sizeVal+5;
			$(input).width(size);
			// order
			var tid = $(this).attr("data-line-id");
			$(this).removeClass("odd even");
			if (i%2==0) $(this).addClass("even");
			else $(this).addClass("odd");
			if (typeof sortit != 'undefined') todoist_sendCommand('set ' + name + ' updateTask ID:'+ tid + ' order="' + i + '"');
			i++;
		});
	}

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
		$(lastEl).before('<tr id="'+ name + "_" + id +'" data-data="true" data-line-id="' + id +'" class="sortit ' + cl +'">\n' +
	  					'	<td class="col1  todoist_col1">\n'+
	  					'   <div class=\"todoist_move\"></div>\n'+
	  					'		<input class="todoist_checkbox_' + name + '" type="checkbox" id="check_' + id + '" data-id="' + id + '" />\n'+
	  					' </td>\n' +
	  					'	<td class="col1">\n'+
	  					' 	<span class="todoist_task_text" data-id="' + id + '">' + title + '</span>\n'+
	  					'   <input type="text" data-id="' + id + '" style="display:none;" class="todoist_input_' + name +'" value="' + title + '" />'+
	  					' </td>\n' +
	  					' <td class="col2">\n' +
	  					' 	<a href="#" class="todoist_delete_' + name + '" data-id="' + id +'">\n'+
	  					'			x\n'+
	  					' 	</a>\n'+
	  					'	</td>\n'+
	           	'</tr>\n'
	  );
	  todoist_refreshTable(name);
	  todoist_getSizes();
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
		$('.sortable').css('max-height',height);
		$('.sortable').css('height',height);
	}

	$(document).ready(function(){
		todoist_getSizes();
		$('.todoist_name').each(function() {
			var name = $(this).val();
			todoist_refreshTable(name);
			$('#todoist_' + name + '_table').on('mouseover','tr.sortit',function(e) {
				$(this).find('div.todoist_move').addClass('todoist_sortit_handler');
			});
			$('#todoist_' + name + '_table').on('mouseout','tr.sortit',function(e) {
				$(this).find('div.todoist_move').removeClass('todoist_sortit_handler');
			});
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
				var width=$(this).width()+20;
				$(this).hide();
				$("input[data-id='" + id +"']").val(val);
				$("input[data-id='" + id +"']").show();
				//$("input[data-id='" + id +"']").width(width);
				$("input[data-id='" + id +"']").focus();
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
				}
				if (e.type=='keypress') {
					resizable(this,7);
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
		$( ".sortable" ).sortable({
			axis: 'y',
			revert: true,
			items: "> tbody > tr.sortit",
			handle: ".todoist_sortit_handler",
			forceHelperSize: true,
			placeholder: "sortable-placeholder",
			helper: fixHelper,
			start: function( event, ui ) { 
				ui.item.css('background','#111111');
				var width = ui.item.innerWidth();
				ui.placeholder.css("width",width); 
				var height = ui.item.innerHeight();
				ui.placeholder.css("height",height); 
			},
			stop: function (event,ui) {
				var parent = ui.item.parent().parent();
				var id = $(parent).attr('id');
				var name = id.split("_")[1];
				ui.item.css('background','');
				todoist_refreshTable(name,1);
			}
		}).disableSelection();
	});

}