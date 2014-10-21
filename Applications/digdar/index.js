// Settings which can be modified

// handle jQuery plugin naming conflict between jQuery UI and Bootstrap
$.widget.bridge('uibutton', $.ui.button);
$.widget.bridge('uitooltip', $.ui.tooltip);

var app_id = 'digdar';  
var root_url = '';
//var root_url = 'http://10.0.1.221';      // Test local
//var root_url = 'http://192.168.53.133';  // Test remote and local
//var root_url = 'http://192.168.1.100';   // Default RedPitaya IP
var start_app_url = root_url + '/bazaar?start=' + app_id;
var stop_app_url = root_url + '/bazaar?stop=';
var get_url = root_url + '/data';
var post_url = root_url + '/data';
var store_params_url = root_url + '/store_params';  // called with POST
var load_params_url = root_url + '/load_params';  // called with GET
var load_factory_params_url = root_url + '/load_factory_params';  // called with GET

var update_interval = 50;              // Update interval for PC, milliseconds
var update_interval_mobdev = 500;      // Update interval for mobile devices, milliseconds 
var request_timeout = 3000;            // Milliseconds
var long_timeout = 20000;              // Milliseconds
var meas_panel_dec = 5;                // Decimation for numerical measure panel to make it human readable
var meas_panel_dec_mobdev = 1;         // Decimation for numerical measure panel for mobile devices
var points_per_px = 5;                 // How many points per pixel should be drawn. Set null for unlimited (will disable client side decimation).
var xdecimal_places = 2;               // Number of decimal places for the xmin/xmax values. Maximum supported are 12.
var trigger_level_xdecimal_places = 4; // Number of decimal places for trigger level tooltip
var range_offset = 1;                  // Percentages

var xmin = -1000000;
var xmax = 1000000;  

var time_range_max = [130, 1000, 8, 130, 1, 8];
var range_steps = [0.5, 1, 2, 5, 10, 20, 50, 100];

var plot_options = {
    colors: ['#D22D2D', '#10ff10', '#0000ff', '#101010'],    // video: red, trigger: green, azimuth: blue, heading: black
    lines: { lineWidth: 1, show: true, steps: true },
    selection: { mode: 'xy' },
    zoom: { interactive: true, trigger: null },
    xaxis: { min: xmin, max: xmax },
    grid: { borderWidth: 0 },
    legend: { noColumns: 2, margin: [0, 0], backgroundColor: 'transparent' },
    touch: { autoWidth: false, autoHeight: false },
    shadowSize: 0,
};

// Settings which should not be modified

var update_timer = null;
var zoompan_timer = null;
var downloading = false;
var sending = false;
var send_que = false;
var use_long_timeout = false;
var trig_dragging = false;
var touch_last_y = 0;
var user_editing = false;
var app_started = false;
var last_get_failed = false;
var refresh_counter = 0;
var autorun = 1;
var datasets = [];
var plot = null;
var params = {
    original: null,
    local: null
};

// Default parameters - posted after server side app is started 
var def_params = {
    en_avg_at_dec: 1,
    trig_source: 3,
    trig_mode: 1
}; 

// On page loaded

$(function() { 
    
    // Show different buttons on touch screens    
    if(window.ontouchstart === undefined) {
        $('.btn-lg').removeClass('btn-lg');
        $('#accordion .btn, .modal .btn').addClass('btn-sm');
        $('#btn_zoompan').remove();
        $('#btn_zoomin, #btn_zoomout, #btn_pan').show();
    }
    else {
        update_interval = update_interval_mobdev;
        $('#btn_zoomin, #btn_zoomout, #btn_pan').remove();
        $('#btn_zoompan').show();
    }
    
    // Add application ID in the message from modal popup
    $('.app-id').text(app_id);
    
    // Disable all controls until the params state is loaded for the first time 
    $('input, select, button', '.container').prop('disabled', true);
    
    // Events binding for trigger controls

    $('#trigger_canvas').on({
        'mousedown touchstart': function(evt) {
            
            // Ignore the event if trigger source is External or mode is not Normal
            if(!params.original || params.original.trig_mode != 1 || params.original.trig_source == 2) {
                return;
            }
            
            trig_dragging = true;
            $('input, select', '#accordion').blur();
            mouseDownMove(this, evt);
            evt.preventDefault();
            return false;
        },
        'mousemove touchmove': function(evt) {
            if(! trig_dragging) {
                return;
            }
            mouseDownMove(this, evt);
            evt.preventDefault();
            return false;
        },
        'mouseup mouseout touchend': mouseUpOut
    });
    
    $('input,select', '#accordion').on('focus', function() {
        user_editing = true;
    });
    
    $('#trig_mode').on('change', function() {
        onDropdownChange($(this), 'trig_mode', true);
        
        // Autorun if trigger mode is Auto(0) or Normal(1), stop if it is Single(2).
        autorun = (params.local.trig_mode == 2 ? 0 : 1); 
        runStop();
    });

    function handleExciteLevel (event, ui) {
        var level = ui.value || $('#excite_level').spinner("value");
        var exciteName = exciteParamName(params.local.trig_source);
        if (exciteName != undefined) {
            params.local[exciteName] = level;
            sendParams();
        }
        return true;
    };

    function handleRelaxLevel (event, ui) {
        var level = ui.value || $('#relax_level').spinner("value");
        var relaxName = relaxParamName(params.local.trig_source);
        if (relaxName != undefined) {
            params.local[relaxName] = level;
            sendParams();
        }
        return true;
    };

    $('#excite_level').spinner({min:-1, max:1, step:0.01, page:10, value:0, spin:handleExciteLevel, change:handleExciteLevel})
        .on('keypress', function(e) {
            if(e.keyCode == 13) {
                $(this).blur();
            }
        });

    $('#relax_level').spinner({min:-1, max:1, step:0.01, page:10, value:0, spin:handleRelaxLevel, change:handleRelaxLevel})
        .on('keypress', function(e) {
            if(e.keyCode == 13) {
                $(this).blur();
            }
        });

    function handleTrigDelay (event, ui) {
        var level = ui.value || $('#digdar_trig_delay').spinner("value");
        params.local.digdar_trig_delay = level / 8;
        sendParams();
        return true;
    };


    $('#digdar_trig_delay').spinner({min:0, max:1e8, step:8, page:50, value:0, spin:handleTrigDelay, change:handleTrigDelay})
        .on('keypress', function(e) {
            if(e.keyCode == 13) {
                $(this).blur();
            }
        });    

    function handleLatencyLevel (event, ui) {
        var level = ui.value || $('#digdar_latency').spinner("value");
        var latencyName = latencyParamName(params.local.trig_source);
        if (latencyName != undefined) {
            params.local[latencyName] = level / 8;
            sendParams();
        }
        return true;
    };
    
    $('#digdar_latency').spinner({min:0, max:125e6, step:8, page:50, value:0, spin:handleLatencyLevel, change:handleLatencyLevel})
        .on('keypress', function(e) {
            if(e.keyCode == 13) {
                $(this).blur();
            }
        });    
    
    $('#trig_source').on('change', function() { onDropdownChange($(this), 'trig_source'); });

    $('#relax_level,#excite_level,#digdar_trig_delay,#digdar_latency').focus(function(e) {user_editing=true;});
    $('#relax_level,#excite_level,#digdar_trig_delay,#digdar_latency').blur(function(e) {user_editing=false;});

    // Events binding for range controls
    $('#range_x_minus, #range_x_plus').on('click', function () {
        var nearest = $(this).data('nearest');
        
        if(nearest && plot) {
            var options = plot.getOptions();
            var axes = plot.getAxes();
            var min = (options.xaxes[0].min !== null ? options.xaxes[0].min : axes.xaxis.min);
            var max = (options.xaxes[0].max !== null ? options.xaxes[0].max : axes.xaxis.max);
            var unit = $(this).data('unit');
            
            // Convert nanoseconds to milliseconds.
            if(unit == 'ns') {
                nearest /= 1000;
            }
            
            var center = (min + max) / 2;
            var half = nearest / 2;
            min = center - half;
            max = center + half;

            options.xaxes[0].min = min;
            options.xaxes[0].max = max;

            plot.setupGrid();
            plot.draw();
            
            params.local.xmin = min;
            params.local.xmax = max;       
            
            updateRanges();
            $(this).tooltip($(this).prop('disabled') === true ? 'hide' : 'show');
            sendParams(true);
        }
    });
    
    $('#range_y_minus, #range_y_plus').on('click', function() {
        var nearest = $(this).data('nearest');
        
        if(nearest && plot) {
            var options = plot.getOptions();
            var axes = plot.getAxes();
            var min = (options.yaxes[0].min !== null ? options.yaxes[0].min : axes.yaxis.min);
            var max = (options.yaxes[0].max !== null ? options.yaxes[0].max : axes.yaxis.max);
            var unit = $(this).data('unit');
            
            // Convert millivolts to volts.
            if(unit == 'mV') {
                nearest /= 1000;
            }
            
            var center = (min + max) / 2;
            var half = nearest / 2;
            min = center - half;
            max = center + half;
            
            options.yaxes[0].min = min;
            options.yaxes[0].max = max;

            plot.setupGrid();
            plot.draw();
            
            updateRanges();
            $(this).tooltip($(this).prop('disabled') === true ? 'hide' : 'show');
            updateTriggerSlider();
        }
    });
    
    $('#offset_x_minus, #offset_x_plus').on('click', function() {
        if(plot) {
            var direction = ($(this).attr('id') == 'offset_x_minus' ? 'left' : 'right');
            var options = plot.getOptions();
            var axes = plot.getAxes();
            var min = (options.xaxes[0].min !== null ? options.xaxes[0].min : axes.xaxis.min);
            var max = (options.xaxes[0].max !== null ? options.xaxes[0].max : axes.xaxis.max);
            var offset = (max - min) * range_offset/100;
            
            if(direction == 'left') {
                min -= offset;
                max -= offset;
            }
            else {
                min += offset;
                max += offset;
            }
            
            options.xaxes[0].min = min;
            options.xaxes[0].max = max;

            plot.setupGrid();
            plot.draw();
            
            params.local.xmin = min;
            params.local.xmax = max;
            
            updateRanges();
            sendParams(true);
        }
    });
    
    $('#offset_y_minus, #offset_y_plus').on('click', function() {
        if(plot) {
            var direction = ($(this).attr('id') == 'offset_y_minus' ? 'down' : 'up');
            var options = plot.getOptions();
            var axes = plot.getAxes();
            var min = (options.yaxes[0].min !== null ? options.yaxes[0].min : axes.yaxis.min);
            var max = (options.yaxes[0].max !== null ? options.yaxes[0].max : axes.yaxis.max);
            var offset = (max - min) * range_offset/100;
            
            if(direction == 'down') {
                min -= offset;
                max -= offset;
            }
            else {
                min += offset;
                max += offset;
            }
            
            options.yaxes[0].min = min;
            options.yaxes[0].max = max;

            plot.setupGrid();
            plot.draw();
            
            updateRanges();
            updateTriggerSlider();
        }
    });
    
    // Events binding for gain controls
    
    $('#gain_ch1_att').on('change', function() { onDropdownChange($(this), 'prb_att_ch1'); });
    $('#gain_ch1_sett').on('change', function() { onDropdownChange($(this), 'gain_ch1'); });
    $('#gain_ch2_att').on('change', function() { onDropdownChange($(this), 'prb_att_ch2'); });
    $('#gain_ch2_sett').on('change', function() { onDropdownChange($(this), 'gain_ch2'); });
    
    // Modals
    
    $('#modal_err, #modal_app, #modal_confirm_store_params').modal({ show: false, backdrop: 'static', keyboard: false });
    
    $('#btn_switch_app').on('click', function() {
        var newapp_id = $('#new_app_id').text();
        if(newapp_id.length) {
            location.href = location.href.replace(app_id, newapp_id);
        }
    });
    
    $('.btn-app-restart').on('click', function() {
        location.reload();
    });
    
    $('#btn_retry_get').on('click', function() {
        $('#modal_err').modal('hide');
        updateGraphData();
    });
    
    $('.btn-close-modal').on('click', function() {
        $(this).closest('.modal').modal('hide');
    });

    $('#btn_maybe_store_digdar_params').on('click', function() {
        $('#modal_confirm_store_params').modal('show');
    });

    $('#btn_store_digdar_params').on('click', function() {
        storeDigdarParams();
        $('#modal_confirm_store_params').modal('hide');
    });

    $('#btn_cancel_store_digdar_params').on('click', function() {
        $('#modal_confirm_store_params').modal('hide');
    });

    $('#btn_maybe_load_digdar_params').on('click', function() {
        $('#modal_confirm_load_params').modal('show');
    });

    $('#btn_load_digdar_params').on('click', function() {
        loadDigdarParams();
        $('#modal_confirm_load_params').modal('hide');
    });

    $('#btn_cancel_load_digdar_params').on('click', function() {
        $('#modal_confirm_load_params').modal('hide');
    });

    $('#btn_maybe_load_digdar_factory_params').on('click', function() {
        $('#modal_confirm_load_factory_params').modal('show');
    });

    $('#btn_load_digdar_factory_params').on('click', function() {
        loadDigdarFactoryParams();
        $('#modal_confirm_load_factory_params').modal('hide');
    });

    $('#btn_cancel_load_digdar_factory_params').on('click', function() {
        $('#modal_confirm_load_factory_params').modal('hide');
    });

    $('#btn_download_digdar_params').on('click', function() {
        $('#input_json_params').val(JSON.stringify(params.local));
        $('#frm_download_digdar_params').submit();
    });

    $('#btn_maybe_upload_digdar_params').on('click', function() {
        $('#modal_upload_digdar_params').modal('show');
    });
    
    $('#btn_upload_digdar_params').on('click', function() {
        var reader = new FileReader();
        reader.onload = function(e) {
            $('#modal_upload_digdar_params').modal('hide');
            params.local = JSON.parse(e.target.result.toString());
            sendParams();
        };
        reader.readAsText($('#input_upload_digdar_params')[0].files[0]);
    });

    $('#btn_cancel_upload_digdar_params').on('click', function() {
        $('#modal_upload_digdar_params').modal('hide');
    });

    // Other event bindings
    
    $('#trigger_tooltip').tooltip({
        title: '',
        trigger: 'manual',
        placement: 'auto left',
        animation: false
    });
    
    $('.btn').on('click', function() {
        var btn = $(this);
        setTimeout(function() { btn.blur(); }, 10);
    });
    
    $('#btn_toolbar .btn').on('blur', function() {
        $(this).removeClass('active');
    });
    
    $(document).on('click', '#accordion > .panel > .panel-heading', function(event) {
        $(this).next('.panel-collapse').collapse('toggle');
        event.stopImmediatePropagation();
    });
    
    // Tooltips for range buttons
    $('#range_x_minus, #range_x_plus, #range_y_minus, #range_y_plus').tooltip({
        container: 'body'
    });
    
    // Load first data
    updateGraphData();
    
    // Stop the application when page is unloaded
    window.onbeforeunload = function() { 
        $.ajax({
            url: stop_app_url,
            async: false
        });
    };

});

function exciteParamName(trig_source) {
    switch (trig_source) {
    case 0:
        return "trig_level";
    case 3:
        return "digdar_trig_excite";
    case 4:
        return "digdar_acp_excite";
    case 5:
        return "digdar_arp_excite";
    }
    return undefined;
};

function relaxParamName(trig_source) {
    switch (trig_source) {
    case 0:
        return "trig_level";
    case 3:
        return "digdar_trig_relax";
    case 4:
        return "digdar_acp_relax";
    case 5:
        return "digdar_arp_relax";
    }
    return undefined;
};

    function latencyParamName(trig_source) {
        switch (trig_source) {
        case 3:
            return "digdar_trig_latency";
        case 4:
            return "digdar_acp_latency";
        case 5:
            return "digdar_arp_latency";
        }
        return undefined;
    };


function startApp() {
    $.get(
        start_app_url
    )
        .done(function(dresult) {
            if(dresult.status == 'ERROR') {
                showModalError((dresult.reason ? dresult.reason : 'Could not start the application.'), true);
            }
            else {
                $.post(
                    post_url, 
                    JSON.stringify({ datasets: { params: def_params } })
                )
                    .done(function(dresult) {
                        app_started = true;
                        updateGraphData();      
                    })
                    .fail(function() {
                        showModalError('Could not initialize the application with default parameters.', false, true);
                    });
            }
        })
        .fail(function() {
            showModalError('Could not start the application.', true);
        });
}

function showModalError(err_msg, retry_btn, restart_btn, ignore_btn) {
    var err_modal = $('#modal_err');
    
    err_modal.find('#btn_retry_get')[retry_btn ? 'show' : 'hide']();
    err_modal.find('.btn-app-restart')[restart_btn ? 'show' : 'hide']();
    err_modal.find('#btn_ignore')[ignore_btn ? 'show' : 'hide']();
    err_modal.find('.modal-body').html(err_msg);
    err_modal.modal('show');
}   

function updateGraphData() {
    if(downloading) {
        return;
    }
    if(update_timer) {
        clearTimeout(update_timer);
        update_timer = null;
    }
    downloading = true;
    
    // Send params if there are any unsent changes
    sendParams();
    
    var arun_before_ajax = autorun;
    var long_timeout_used = use_long_timeout;
    
    $.ajax({
        url: get_url,
        timeout: (use_long_timeout ? long_timeout : request_timeout),
        cache: false
    })
        .done(function(dresult) {
            last_get_failed = false;
            
            if(dresult.status === 'ERROR') {
                if(! app_started) {
                    startApp();
                }
                else {
                    showModalError((dresult.reason ? dresult.reason : 'Application error.'), true, true);
                }
            }
            else if(dresult.datasets !== undefined && dresult.datasets.params !== undefined) {
                // Check if the application started on the server is the same as on client
                if(app_id !== dresult.app.id) {
                    if(! app_started) {
                        startApp();
                    }
                    else {
                        $('#new_app_id').text(dresult.app.id);
                        $('#modal_app').modal('show');
                    }
                    return;
                }
                
                app_started = true;
                
                // Check if trigger mode (which may switch autorun) was changed during ajax request
                var arun_after_ajax = autorun;
                
                datasets = [];
                var chanNames = ["Video", "Trigger", "Azimuth / ACP", "Heading / ARP"];
                for(var i=0; i<dresult.datasets.g1.length; i++) {
                    dresult.datasets.g1[i].color = i;
                    dresult.datasets.g1[i].label = chanNames[i];
                    datasets.push(dresult.datasets.g1[i]);
                }
                
                if(! plot) {
                    initPlot(dresult.datasets.params);
                }
                else {
                    // Apply the params state received from server if not in edit mode
                    if(! user_editing) {
                        loadParams(dresult.datasets.params);
                        
                        // Restore the autorun value modified by loadParams 
                        if(arun_before_ajax != arun_after_ajax) {
                            autorun = arun_after_ajax; 
                        }
                    }
                    // Time units must be always updated
                    else {
                        updateTimeUnits(dresult.datasets.params);
                    }
                    
                    // Force X min/max
                    if(dresult.datasets.params.forcex_flag == 1) {
                        var options = plot.getOptions();
                        options.xaxes[0].min = dresult.datasets.params.xmin;
                        options.xaxes[0].max = dresult.datasets.params.xmax;
                    }
                    
                    // Redraw the plot using new datasets
                    plot.setData(filterData(datasets, plot.width()));
                    plot.setupGrid();
                    plot.draw();
                    $('#info_ch2_freq').html(convertHz(params.original.digdar_trig_rate));
                    $('#info_ch2_capture_freq').html(convertHz(params.original.digdar_capture_rate));
                    $('#info_ch2_period').html(convertSec(1.0 / params.original.digdar_trig_rate));
                    $('#info_acp_rate').html(convertHz(params.original.digdar_acp_rate));
                    var acpsPerArp = params.original.digdar_acps_per_arp;
                    $('#info_acps_per_arp').html(acpsPerArp);
                    $('#info_arp_rate').html(Math.round(params.original.digdar_arps_rate * 10) / 10);
                    var canv = $(".flot-base");
                    var xc = 350, yc=225, radius=200;
                    canv.drawArc({
                        strokeStyle: 'rgba(255, 255, 0, 0.1)',
                        fillStyle: 'rgba(255, 255, 0, 0.1)',
                        strokeWidth: 1,
                        closed: true,
                        x: xc, y: yc,
                        radius: radius,
                        // start and end angles in degrees
                        start: 0, end: 360
                    });                                               
                    canv.drawLine({
                        strokeStyle: 'rgba(255, 255, 0, .4)',
                        strokeWidth: 10,
                        x1: xc + radius * Math.cos(2 * Math.PI * (params.original.digdar_acps_seen % acpsPerArp) / acpsPerArp),
                        y1: yc + radius * Math.sin(2 * Math.PI * (params.original.digdar_acps_seen % acpsPerArp) / acpsPerArp),
                        x2: xc, y2: yc
                    });
                }
                
                if(! trig_dragging) {
                    updateTriggerSlider();
                }
                
                updateRanges();

                if(autorun || dresult.status === 'AGAIN') {
                    if(autorun) {
                        $('#btn_single_div').hide();
                    }
                    update_timer = setTimeout(function() {
                        updateGraphData();
                    }, update_interval);
                }
                else {
                    $('#btn_single_div').show();
                    $('#btn_single').prop('disabled', false);
                }
            }
            else {
                showModalError('Wrong application data received.', true, true);
            }
        })
        .fail(function(jqXHR, textStatus, errorThrown) {
            if(last_get_failed) {
                showModalError('Data receiving failed.<br>Error status: ' + textStatus, true, true);
                last_get_failed = false;
            }
            else {
                last_get_failed = true;
                downloading = false;
                updateGraphData();  // One more try
            }
        })
        .always(function() {
            if(! last_get_failed) {
                downloading = false;
                
                if(params.local) {
                    // Disable trigger level input if trigger mode is continuous
                    if(params.original.trig_mode == 0) {
                        $('#excite_level').prop('disabled', true);
                        if($('#excite_level').is(':focus')) {
                            $('#excite_level').blur();
                        }
                        $('#relax_level').prop('disabled', true);
                        if($('#relax_level').is(':focus')) {
                            $('#relax_level').blur();
                        }
                        $('#trig_source').prop('disabled', true);
                        if($('#trig_source').is(':focus')) {
                            $('#trig_source').blur();
                        }
                        $('#apply_trig_level').hide().parent().removeClass('input-group');
                    }
                    else {
                        $('#relax_level').prop('disabled', false);
                        $('#excite_level').prop('disabled', false);
                        $('#trig_source').prop('disabled', false);
                    }
                    
                    // Manage the state of other components
                    $('#accordion').find('input,select').not('#excite_level').not('#relax_level').not('#trig_source').prop('disabled', false);
                    $('.btn').not('#btn_single, #range_y_plus, #range_y_minus, #range_x_plus, #range_x_minus').prop('disabled', false);

                    if (params.local.trig_source == 3)
                        $('#digdar_trig_delay_div').show();
                    else
                        $('#digdar_trig_delay_div').hide();
                    if (params.local.trig_source != 2)
                        $('#digdar_latency_div').show();
                    else
                        $('#digdar_latency_div').hide();
                }
            }
            
            if(long_timeout_used) {
                use_long_timeout = false;
            }
        });
}

function initPlot(init_params) {
    var plot_holder = $('#plot_holder');
    var ymax = init_params.gui_reset_y_range / 2;
    var ymin = ymax * -1;
    
    // Load received params
    loadParams(init_params);
    
    // When xmin/xmax are null, the min/max values of received data will be used. For ymin/ymax use the gui_reset_y_range param.
    $.extend(true, plot_options, {
        xaxis: { min: null, max: null },
        yaxis: { min: ymin, max: ymax }
    });
    
    // Local optimization    
    var filtered_data = filterData(datasets, plot_holder.width());
    
    // Plot first creation and drawing
    plot = $.plot(
        plot_holder, 
        filtered_data,
        plot_options
    );
    
    // Selection
    plot_holder.on('plotselected', function(event, ranges) {
        
        // Clamp the zooming to prevent eternal zoom
        if(ranges.xaxis.to - ranges.xaxis.from < 0.00001) {
            ranges.xaxis.to = ranges.xaxis.from + 0.00001;
        }
        if(ranges.yaxis.to - ranges.yaxis.from < 0.00001) {
            ranges.yaxis.to = ranges.yaxis.from + 0.00001;
        }
        
        // Do the zooming
        plot = $.plot(
            plot_holder, 
            getData(ranges.xaxis.from, ranges.xaxis.to),
            $.extend(true, plot_options, {
                xaxis: { min: ranges.xaxis.from, max: ranges.xaxis.to },
                yaxis: { min: ranges.yaxis.from, max: ranges.yaxis.to }
            })
        );
        
        params.local.xmin = parseFloat(ranges.xaxis.from.toFixed(xdecimal_places));
        params.local.xmax = parseFloat(ranges.xaxis.to.toFixed(xdecimal_places));
        
        updateTriggerSlider();
        sendParams(true);
    });
    
    // Zoom / Pan
    plot_holder.on('plotzoom plotpan touchmove touchend', function(event) {
        
        if(zoompan_timer) {
            clearTimeout(zoompan_timer);
            zoompan_timer = null;
        }
        
        zoompan_timer = setTimeout(function() {
            zoompan_timer = null;
            
            var xaxis = plot.getAxes().xaxis;
            params.local.xmin = parseFloat(xaxis.min.toFixed(xdecimal_places));
            params.local.xmax = parseFloat(xaxis.max.toFixed(xdecimal_places));
            
            updateTriggerSlider();
            sendParams(true);
            
        }, 250);
    });
}

function onDropdownChange(that, param_name, do_get) {
    params.local[param_name] = parseInt(that.val());
    sendParams(do_get);
    that.blur();
    user_editing = false;
}

function loadParams(orig_params) {
    if(! $.isPlainObject(orig_params)) {
        return;
    }
    
    // Ignore xmin/xmax values received from server. That values must be used only on AUTO button click 
    // and on ForceX flag, but that is done before the sendParams() function is called.
    if(plot) {
        var options = plot.getOptions();
        if(options.xaxes[0].min && options.xaxes[0].max) {
            orig_params.xmin = options.xaxes[0].min;
            orig_params.xmax = options.xaxes[0].max;
        }
    }
    
    // Same data in local and original params
    params.original = $.extend({}, orig_params);
    params.local = $.extend({}, params.original);

    // Autorun if trigger mode is Auto(0) or Normal(1), stop if it is Single(2)
    autorun = (params.original.trig_mode == 2 ? 0 : 1);
    
    // Show the Single button when not in autorun mode
    if (autorun) {
        $('#btn_single_div').hide();
    } else {
        $('#btn_single_div').show();
        $('#btn_single').prop('disabled', false);
    }

    $('#trig_mode').val(params.original.trig_mode);
    $('#trig_source').val(params.original.trig_source);
    $('#trig_edge').val(params.original.trig_edge);
    var scale = (params.original.trig_source == 0 ? params.original.scale_ch1 : params.original.scale_ch2);
    $('#excite_level').val(floatToLocalString(params.original[ exciteParamName(params.original.trig_source)] * scale));
    $('#relax_level').val(floatToLocalString(params.original[ relaxParamName(params.original.trig_source)] * scale));
    $('#digdar_trig_delay').val(floatToLocalString(params.original.digdar_trig_delay * 8));
    $('#digdar_latency').val(floatToLocalString(params.original[ latencyParamName(params.original.trig_source)] * 8));

    if ((refresh_counter++ % meas_panel_dec) == 0) {
        $('#info_ch1_min').html(floatToLocalString(shortenFloat(params.original.meas_min_ch1)));
        $('#info_ch1_max').html(floatToLocalString(shortenFloat(params.original.meas_max_ch1)));
        $('#info_ch1_amp').html(floatToLocalString(shortenFloat(params.original.meas_amp_ch1)));
        $('#info_ch1_avg').html(floatToLocalString(shortenFloat(params.original.meas_avg_ch1)));
        $('#info_ch1_freq').html(convertHz(params.original.meas_freq_ch1));
        $('#info_ch1_period').html(convertSec(params.original.meas_per_ch1));

        $('#info_ch2_min').html(floatToLocalString(shortenFloat(params.original.meas_min_ch2)));
        $('#info_ch2_max').html(floatToLocalString(shortenFloat(params.original.meas_max_ch2)));
        $('#info_ch2_amp').html(floatToLocalString(shortenFloat(params.original.meas_amp_ch2)));
        $('#info_ch2_avg').html(floatToLocalString(shortenFloat(params.original.meas_avg_ch2)));
        $('#info_ch2_freq').html(convertHz(params.original.meas_freq_ch2));
        $('#info_ch2_period').html(convertSec(params.original.meas_per_ch2));
    }
    
    $('#gain_ch1_att').val(params.original.prb_att_ch1);
    $('#gain_ch1_sett').val(params.original.gain_ch1);
    $('#gain_ch2_att').val(params.original.prb_att_ch2);
    $('#gain_ch2_sett').val(params.original.gain_ch2);
    
    if(params.original.en_avg_at_dec) {
        $('#btn_avg').removeClass('btn-default').addClass('btn-primary');
    }
    else {
        $('#btn_avg').removeClass('btn-primary').addClass('btn-default');
    }
    
    updateTimeUnits(orig_params);
    $('#ytitle').show();
}

function updateTimeUnits(new_params) {
    if(! $.isPlainObject(new_params)) {
        return;
    } 
    
    params.original.time_units = params.local.time_units = new_params.time_units;

    var timeu_lbl = (params.original.time_units == 0 ? 'μs' : (params.original.time_units == 1 ? 'ms' : 's'));
    $('#xtitle').text('Time [ ' + timeu_lbl + ' ]');
}

function isParamChanged() {
    if(params.original) {
        for(var key in params.original) {
            if(params.original[key] != params.local[key]) {
                return true;
            }
        }
    }
    return false;
}

function sendParams(refresh_data, force_send, single_btn) {
    if(sending || (force_send !== true && !isParamChanged())) {
        send_que = sending;
        return;
    }
    
    var auto_flag = params.local.auto_flag;  // Keep the value of auto_flag, because in POST response it is always 0
    sending = true;
    params.local.single_btn = (single_btn === true ? 1 : 0);
    use_long_timeout = !!auto_flag;
    
    $.ajax({
        type: 'POST',
        url: post_url,
        data: JSON.stringify({ datasets: { params: params.local } }),
        timeout: (use_long_timeout ? long_timeout : request_timeout),
        cache: false
    })
        .done(function(dresult) {
            // OK: Load the params received as POST result
            if(dresult.datasets !== undefined && dresult.datasets.params !== undefined) {
                
                // Use the provided min/max values only once after AUTO button was clicked
                if(auto_flag == 1 && dresult.datasets.params.min_y !== dresult.datasets.params.max_y) {
                    var options = plot.getOptions();
                    
                    options.xaxes[0].min = dresult.datasets.params.xmin;
                    options.xaxes[0].max = dresult.datasets.params.xmax;
                    options.yaxes[0].min = dresult.datasets.params.min_y;
                    options.yaxes[0].max = dresult.datasets.params.max_y;
                    
                    // Enable all 4 channels after click on AUTO button
                    if(!$('#btn_ch1').data('checked') || !$('#btn_ch2').data('checked') || !$('#btn_ch3').data('checked') || !$('#btn_ch4').data('checked')) {
                        $('#btn_ch1').data('checked', true).removeClass('btn-default').addClass('btn-primary');
                        $('#btn_ch2').data('checked', true).removeClass('btn-default').addClass('btn-primary');
                        $('#btn_ch3').data('checked', true).removeClass('btn-default').addClass('btn-primary');
                        $('#btn_ch4').data('checked', true).removeClass('btn-default').addClass('btn-primary');
                        redrawPlot();
                    }
                    // All channels are already active, do a quick redraw
                    else {
                        plot.setupGrid();
                        plot.draw();
                    }
                }
                
                if(auto_flag == 0 && dresult.datasets.params.forcex_flag == 1) {
                    var options = plot.getOptions();
                    
                    options.xaxes[0].min = dresult.datasets.params.xmin;
                    options.xaxes[0].max = dresult.datasets.params.xmax;
                    
                    plot.setupGrid();
                    plot.draw();
                }      
                
                loadParams(dresult.datasets.params);
                updateTriggerSlider();
                
                if(refresh_data && !downloading) {
                    updateGraphData();
                } 
            }
            else if(dresult.status == 'ERROR') {
                showModalError((dresult.reason ? dresult.reason : 'Error while sending data (E1).'), false, true, true);
                send_que = false;
            }
            else {
                showModalError('Error while sending data (E2).', false, true, true);
            }
        })
        .fail(function() {
            showModalError('Error while sending data (E3).', false, true, true);
        })
        .always(function() {
            sending = false;
//            user_editing = false;
            
            if(send_que) {
                send_que = false;
                setTimeout(function(refresh_data) {
                    sendParams(refresh_data);
                }, 100);
            }
        });
}

function getData(from, to) {
    var rangedata = new Array();
    for(var i=0; i<datasets.length; i++) {
        if(! $('#btn_ch' + (i+1)).data('checked')) {
            continue;
        }
        rangedata.push({ color: datasets[i].color, label: datasets[i].label, data: [] });
        for(var j=0; j<datasets[i].data.length; j++) {
            if(datasets[i].data[j][0] > to) {
                break;
            }
            if(datasets[i].data[j][0] >= from) {
                rangedata[rangedata.length - 1].data.push(datasets[i].data[j]);
            }
        }
    }
    rangedata = filterData(rangedata, (plot ? plot.width() : $('plot_holder').width()));
    return rangedata;
}

// Use only data for selected channels and do downsamling (data decimation), which is required for 
// better performance. On the canvas cannot be shown too much graph points. 
function filterData(dsets, points) {
    var filtered = [];
    var num_of_channels = 4;

    for(var l=0; l<num_of_channels; l++) {
        if(! $('#btn_ch' + (l+1)).data('checked')) {
            continue;
        }

        i = Math.min(l, dsets.length - 1);

        filtered.push({ color: dsets[i].color, label: dsets[i].label, data: [] });
        
        if(points_per_px === null || dsets[i].data.length > points * points_per_px) {
            var step = Math.ceil(dsets[i].data.length / (points * points_per_px));
            var k = 0;
            for(var j=0; j<dsets[i].data.length; j++) {
                if(k > 0 && ++k < step) {
                    continue;
                }
                filtered[filtered.length - 1].data.push(dsets[i].data[j]);
                k = 1;
            }
        }
        else {
            filtered[filtered.length - 1].data = dsets[i].data.slice(0);
        }
    }
    
    filtered = addTriggerDataSet(filtered);
    return filtered;
}

// Add a data series for the trigger level lines
function addTriggerDataSet(dsets) {

    // Transform trigger levels to real values
    
    var tlev = [params.local[exciteParamName(params.local.trig_source)], params.local[relaxParamName(params.local.trig_source)]];
    
    // Don't add trigger dataset if trigger level is outside the visible area...
    if(plot) {
        var yaxis = plot.getAxes().yaxis;
        if((tlev[0] < yaxis.min || tlev[0] > yaxis.max) && (tlev[1] < yaxis.min || tlev[1] > yaxis.max)) {
            return dsets;
        }
    }
    // ...or trigger mode is continuous
    if(params.local.trig_mode == 0) {
        return dsets;
    }
    // // ...or outside of received data for Y axis
    // var ch1ymin = null, 
    // ch1ymax = null;
    // // Find Y min/max values from data for first visible channel
    // for(var i=0; i<dsets[0].data.length; i++) {
    //     ch1ymin = (ch1ymin === null || ch1ymin > dsets[0].data[i][1] ? dsets[0].data[i][1] : ch1ymin);
    //     ch1ymax = (ch1ymax === null || ch1ymax < dsets[0].data[i][1] ? dsets[0].data[i][1] : ch1ymax);
    // }
    // if(dsets.length > 1) {
    //     var ch2ymin = null, 
    //     ch2ymax = null;
    //     // Find Y min/max values from data for second visible channel
    //     for(var i=0; i<dsets[1].data.length; i++) {
    //         ch2ymin = (ch2ymin === null || ch2ymin > dsets[1].data[i][1] ? dsets[1].data[i][1] : ch2ymin);
    //         ch2ymax = (ch2ymax === null || ch2ymax < dsets[1].data[i][1] ? dsets[1].data[i][1] : ch2ymax);
    //     }
    //     // Check if trigger level is outside of found values
    //     if(tlev < Math.min(ch1ymin, ch2ymin) || tlev > Math.max(ch1ymax, ch2ymax)) {
    //         return dsets;
    //     }
    // }
    // else {
    //     // Check if trigger level is outside of found values
    //     if(tlev < ch1ymin || tlev > ch1ymax) {
    //         return dsets;
    //     }
    // }
    
    var index = 0;
    var dxmin = 0;
    var dxmax = 1;
    
    index = dsets.length;
    if(index && dsets[0].data[0]) {
        dxmin = dsets[0].data[0][0];
        dxmax = dsets[0].data[dsets[0].data.length - 1][0];
    } else {
        var xaxis = plot.getAxes().xaxis;
        dxmin = xaxis.min;
        dxmax = xaxis.max;
    }
    
    var np = 40;
    var excitePts = new Array(np);
    var relaxPts = new Array(np);
    var xx = dxmin;
    var dxx = (dxmax - dxmin) / (np - 1)
    for (i = 0; i < np; ++i, xx += dxx) {
        excitePts[i] = [xx, tlev[0]];
        relaxPts[i] = [xx, tlev[1]];
    }
    var normal = tlev[1] >= tlev[0];
    dsets[index] = { color: "rgb(0, 0, 0)", data: excitePts, shadowSize: 0, points: {show: true, fill:false, radius: 10, symbol:plusSign, lineWidth: 0.5 }, lines: {show: false} };
    dsets[index+1] = { color: "rgb(0, 0, 0)", data: relaxPts, shadowSize: 0, points: {show: true, fill:false,radius: 10, symbol:minusSign, lineWidth: 0.5}, lines: {show: false} };
    
    return dsets;
}

function plusSign(ctx, x, y, radius, shadow) {
    var r2 = radius/2;
    ctx.moveTo(x, y - r2);
    ctx.lineTo(x, y + r2);
    ctx.moveTo(x - r2, y);
    ctx.lineTo(x + r2, y);
}

function minusSign(ctx, x, y, radius, shadow) {
// offset these by radius / 2 to the right so 
// they can be seen when overlain directly on the plusSign symbols
    ctx.moveTo(x, y);
    ctx.lineTo(x + radius, y);
}

function runStop() {
    if(autorun) {
        $('#btn_single_div').hide();
        updateGraphData();
    }
    else {
        $('#btn_single_div').show();
        $('#btn_single').prop('disabled', false);
        if(update_timer) {
            clearTimeout(update_timer);
            update_timer = null;
        }
    }
}

function singleUpdate() {
    if(! autorun) {
        sendParams(true, true, true);
    }
}

function redrawPlot() {
    if(! downloading) {
        if(! plot) {
            updateGraphData();
        }
        else {
            var options = plot.getOptions();
            plot = $.plot(
                plot.getPlaceholder(), 
                filterData(datasets, plot.width()),
                $.extend(true, plot_options, {
                    xaxis: { min: options.xaxes[0].min, max: options.xaxes[0].max },
                    yaxis: { min: options.yaxes[0].min, max: options.yaxes[0].max }
                })
            );
            updateTriggerSlider();        
        }
    }
}

function setVisibleChannels(btn) {
    var other_btn = $(btn.id == 'btn_ch1' ? '#btn_ch2' : '#btn_ch1');
    var btn = $(btn);
    var checked = !btn.data('checked');
    
    btn.data('checked', checked).toggleClass('btn-default btn-primary');
    
    // JMB: the following doesn't seem very important and isn't intuitive                                                 
    // At least one button must be checked, so that at least one graph will be visible.
    //    if(! checked) {
    //      other_btn.data('checked', true).removeClass('btn-default').addClass('btn-primary');
    //    }
    redrawPlot();
}

function autoscaleY() {
    if(! plot) {
        return;
    }
    
    var options = plot.getOptions();
    var axes = plot.getAxes();
    
    // Set Y scale to data min/max + 10%
    options.yaxes[0].min = (axes.yaxis.datamin < 0 ? axes.yaxis.datamin * 1.1 : axes.yaxis.datamin - axes.yaxis.datamin * 0.1); 
    options.yaxes[0].max = (axes.yaxis.datamax > 0 ? axes.yaxis.datamax * 1.1 : axes.yaxis.datamax + axes.yaxis.datamax * 0.1);

    plot.setupGrid();
    plot.draw();
    
    updateRanges();
    updateTriggerSlider();
}

function setAvgAtDec() {
    if(! plot) {
        return;
    }
    
    $('#btn_avg').toggleClass('btn-default btn-primary');

    if($('#btn_avg').hasClass('btn-primary')) {
        params.local.en_avg_at_dec = 1;
    }
    else{
        params.local.en_avg_at_dec = 0;
    }

    sendParams(true, true);
}

function resetZoom() {
    if(! plot) {
        return;
    }
    
    $('#btn_ch1, #btn_ch2, #btn_ch, #btn_ch4').data('checked', true).removeClass('btn-default').addClass('btn-primary');
    
    var ymax = params.original.gui_reset_y_range / 2;
    var ymin = ymax * -1;
    
    $.extend(true, plot_options, {
        xaxis: { min: null, max: null },
        yaxis: { min: ymin, max: ymax }
    });
    
    var options = plot.getOptions();
    options.xaxes[0].min = null;
    options.xaxes[0].max = null;
    options.yaxes[0].min = ymin;
    options.yaxes[0].max = ymax;
    
    plot.setupGrid();
    plot.draw();
    
    params.local.xmin = xmin;
    params.local.xmax = xmax;
    
    sendParams(true, true);
}

function updateZoom() {
    if(! plot) {
        return;
    }
    
    params.local.xmin = 0;
    params.local.xmax = time_range_max[params.local.time_range];
    
    var axes = plot.getAxes();
    var options = plot.getOptions();
    
    options.xaxes[0].min = params.local.xmin;
    options.xaxes[0].max = params.local.xmax;
    options.yaxes[0].min = axes.yaxis.min;
    options.yaxes[0].max = axes.yaxis.max;
    
    plot.setupGrid();
    plot.draw();

    sendParams(true, true);
}

function selectTool(toolname) {
    $('#selzoompan .btn').removeClass('btn-primary').addClass('btn-default');
    $(this).toggleClass('btn-default btn-primary');
    
    if(toolname == 'zoomin') {
        enableZoomInSelection();
    }
    if(toolname == 'zoomout') {
        enableZoomOut();
    }
    else if(toolname == 'pan') {
        enablePanning();
    }
}

function enableZoomInSelection() {
    if(plot_options.hasOwnProperty('selection')) {
        return;
    }
    
    var plot_pholder = plot.getPlaceholder();

    // Disable panning and zoom out
    delete plot_options.pan;
    plot_pholder.off('click.rp');
    
    // Get current min/max for both axes to use them to fix the current view
    var axes = plot.getAxes();
    
    plot = $.plot(
        plot_pholder, 
        plot.getData(),
        $.extend(true, plot_options, {
            selection: { mode: 'xy' },
            xaxis: { min: axes.xaxis.min, max: axes.xaxis.max },
            yaxis: { min: axes.yaxis.min, max: axes.yaxis.max }
        })
    );
}

function enableZoomOut() {
    var plot_pholder = plot.getPlaceholder();
    
    plot_pholder.on('click.rp', function(event) {
        var offset = $(event.target).offset();
        
        plot.zoomOut({
            center: { left: event.pageX - offset.left, top: event.pageY - offset.top },
            amount: 1.2
        });
    });
    
    // Disable zoom in selection and panning
    delete plot_options.selection;
    delete plot_options.pan;
    
    // Get current min/max for both axes to use them to fix the current view
    var axes = plot.getAxes();
    
    plot = $.plot(
        plot_pholder, 
        plot.getData(),
        $.extend(true, plot_options, {
            xaxis: { min: axes.xaxis.min, max: axes.xaxis.max },
            yaxis: { min: axes.yaxis.min, max: axes.yaxis.max }
        })
    );
}

function enablePanning() {
    if(plot_options.hasOwnProperty('pan')) {
        return;
    }
    
    var plot_pholder = plot.getPlaceholder();
    
    // Disable selection zooming and zoom out
    delete plot_options.selection;
    plot_pholder.off('click.rp');
    
    // Get current min/max for both axes to use them to fix the current view
    var axes = plot.getAxes();
    
    plot = $.plot(
        plot_pholder, 
        plot.getData(),
        $.extend(true, plot_options, {
            pan: { interactive: true },
            xaxis: { min: axes.xaxis.min, max: axes.xaxis.max },
            yaxis: { min: axes.yaxis.min, max: axes.yaxis.max }
        })
    );
}

function mouseDownMove(that, evt) {
    var y;
    user_editing = true;
    
    if(evt.type.indexOf('touch') > -1) {
        y = evt.originalEvent.touches[0].clientY - that.getBoundingClientRect().top - plot.getPlotOffset().top;
        touch_last_y = y;
    }
    else {
        y = evt.clientY - that.getBoundingClientRect().top - plot.getPlotOffset().top;
    }
    updateTriggerSlider(y);
    
    $('#trigger_tooltip').data('bs.tooltip').options.title = plot.getAxes().yaxis.c2p(y).toFixed(trigger_level_xdecimal_places);
    $('#trigger_tooltip').tooltip('show');
}

function mouseUpOut(evt) {
    if(trig_dragging) {
        trig_dragging = false;
        
        var y;
        if(evt.type.indexOf('touch') > -1) {
            //y = evt.originalEvent.touches[0].clientY - this.getBoundingClientRect().top - plot.getPlotOffset().top;
            y = touch_last_y;
        }
        else {
            y = evt.clientY - this.getBoundingClientRect().top - plot.getPlotOffset().top;
        }
        
        var scale = (params.local.trig_source == 0 ? params.local.scale_ch1 : params.local.scale_ch2);
        params.local.trig_level = parseFloat(plot.getAxes().yaxis.c2p(y).toFixed(trigger_level_xdecimal_places)) / scale;           
        
        updateTriggerSlider();
        redrawPlot();
        sendParams();
    }
    else {
        user_editing = false;
    }
    $('#trigger_tooltip').tooltip('hide');
}

function updateTriggerSlider(y, update_input) {

    return; 

    if(! plot) {
        return;
    }

    
    var canvas = $('#trigger_canvas')[0];
    var context = canvas.getContext('2d');
    var plot_offset = plot.getPlotOffset();
    var ymax = params.original.gui_reset_y_range / 2;
    var ymin = ymax * -1;
    
    // Transform trigger level to real values
    // TODO: local or original params?
    var scale = (params.local.trig_source == 0 ? params.local.scale_ch1 : params.local.scale_ch2);
    var tlev = params.local.trig_level * scale;

    // If trigger level is outside the predefined ymin/ymax, change the level
    
    if(tlev < ymin) {
        tlev = ymin;
    }
    else if(tlev > ymax) {
        tlev = ymax;
    }
    
    if(y === undefined) {
        if(update_input !== false) {
            $('#trig_level').not(':focus').val(floatToLocalString(tlev));
        }
        y = plot.getAxes().yaxis.p2c(tlev);
    }
    
    // If trigger source is External or mode is Continuous or trigger level is not in visible area, do not show the trigger slider and paint the vertical line with gray
    context.clearRect(0, 0, canvas.width, canvas.height); 
    var yaxis = plot.getAxes().yaxis;
    if(params.original.trig_mode == 0 || tlev < yaxis.min || tlev > yaxis.max || params.original.trig_source == 2) {
        context.lineWidth = 1;
        context.strokeStyle = '#dddddd';
        context.stroke();
        context.beginPath();
        context.moveTo(10, plot_offset.top);
        context.lineTo(10, canvas.height - plot_offset.bottom + 1);
        context.stroke();
    }
    else {
        context.beginPath();
        context.arc(10, y + plot_offset.top, 8, 0, 2 * Math.PI, false);
        context.fillStyle = '#009900';
        context.fill();
        context.lineWidth = 1;
        context.strokeStyle = '#007700';
        context.stroke();
        context.beginPath();
        context.moveTo(10, plot_offset.top);
        context.lineTo(10, canvas.height - plot_offset.bottom + 1);
        context.stroke();
    }
    //    $('#trigger_tooltip').css({ top: y + plot_offset.top });  
}

function updateRanges() {
    var xunit = (params.local.time_units == 0 ? 'μs' : (params.local.time_units == 1 ? 'ms' : 's'));
    var yunit = '';
    var axes = plot.getAxes();
    var xrange = axes.xaxis.max - axes.xaxis.min;
    var yrange = axes.yaxis.max - axes.yaxis.min;
    var yminrange = 1e-4;  // Relative units
    var ymaxrange = 2; // params.original.gui_reset_y_range;
    var xmaxrange = 10.0;  // seconds
    var xminrange = 20e-9; // seconds
    var decimals = 0;

    if(xunit == 'μs' && xrange < 1) {
        xrange *= 1000;
        xunit = 'ns';
    }
    if(xrange < 1) {
        decimals = 1;
    }
    var seconds = (xunit == 'ns' ? 1e-9 : ( xunit == 'μs' ? 1e-6 : (xunit == 'ms' ? 1e-3 : 1)));
    
    if(yrange < 1) {
        yunit = 'mV';
        yrange *= 1000;
        ymaxrange *= 1000;
        yminrange *= 1000;
    }

    $('#range_x').html(+(Math.round(xrange + "e+" + decimals) + "e-" + decimals) + ' ' + xunit);
    $('#range_y').html(Math.floor(yrange) + ' ' + yunit);
    
    var nearest_x = getNearestRanges(xrange);
    var nearest_y = getNearestRanges(yrange);
    
    // X limitations 
    if(nearest_x.next * seconds > xmaxrange) {
        nearest_x.next = null;
        $('#range_x_plus').prop('disabled', true);
    }
    else {
        $('#range_x_plus').prop('disabled', false);
    }
    if(nearest_x.prev * seconds < xminrange) {
        nearest_x.prev = null;
        $('#range_x_minus').prop('disabled', true);
    }
    else {
        $('#range_x_minus').prop('disabled', false);
    }
    
    $('#range_x_minus').data({ nearest: nearest_x.prev, unit: xunit }).data('bs.tooltip').options.title = nearest_x.prev;
    $('#range_x_plus').data({ nearest: nearest_x.next, unit: xunit }).data('bs.tooltip').options.title = nearest_x.next;
    
    // Y limitations
    if(nearest_y.next - nearest_y.prev >= ymaxrange) {
        nearest_y.next = null;
        $('#range_y_plus').prop('disabled', true);
    }
    else {
        $('#range_y_plus').prop('disabled', false);
    }
    if(nearest_y.prev < yminrange) {
        nearest_y.prev = null;
        $('#range_y_minus').prop('disabled', true);
    }
    else {
        $('#range_y_minus').prop('disabled', false);
    }
    
    $('#range_y_minus').data({ nearest: nearest_y.prev, unit: yunit }).data('bs.tooltip').options.title = nearest_y.prev;
    $('#range_y_plus').data({ nearest: nearest_y.next, unit: yunit }).data('bs.tooltip').options.title = nearest_y.next;
}

function getNearestRanges(number) {
    var log10 = Math.floor(Math.log(number) / Math.LN10); 
    var normalized = number / Math.pow(10, log10);    
    var i = 0;
    var prev = null;
    var next = null;
    
    while(i < range_steps.length - 1) {
        var ratio = range_steps[i+1] / normalized;
        if(ratio > 0.99 && ratio < 1.01) {
            prev = range_steps[i];
            next = range_steps[i+2];
            break;
        }
        if(range_steps[i] < normalized && normalized < range_steps[i+1]) {
            prev = range_steps[i];
            next = range_steps[i+1];
            break;
        }
        i++;
    }

    return { 
        prev: prev * Math.pow(10, log10), 
        next: next * Math.pow(10, log10) 
    };
}

function serverAutoScale() {
    params.local.auto_flag = 1;
    sendParams(true);
}

function getLocalDecimalSeparator() {
    var n = 1.1;
    return n.toLocaleString().substring(1,2);
}

function parseLocalFloat(num) {
    return +(num.replace(getLocalDecimalSeparator(), '.'));
}

function floatToLocalString(num) {
    // Workaround for a bug in Safari 6 (reference: https://github.com/mleibman/SlickGrid/pull/472)
    //return num.toString().replace('.', getLocalDecimalSeparator());
    return (num + '').replace('.', getLocalDecimalSeparator());
}

function shortenFloat(value) {
    return value.toFixed(Math.abs(value) >= 10 ? 1 : 3);
}

function convertHz(value) {
    var unit = '';
    var decsep = getLocalDecimalSeparator();
    
    if(value >= 1e6) {
        value /= 1e6;
        unit = '<span class="unit">MHz</span>';
    }
    else if(value >= 1e3) {
        value /= 1e3;
        unit = '<span class="unit">kHz</span>';
    }
    else {
        unit = '<span class="unit">Hz</span>';
    }

    // Fix to 4 decimal digits in total regardless of the decimal point placement
    var eps = 1e-2;
    if (value >= 100 - eps) {
        value = value.toFixed(1);
    }
    else if  (value >= 10 - eps) {
        value = value.toFixed(2);
    }
    else {
        value = value.toFixed(3);
    }
    
    value = (value == 0 ? '---' + decsep + '-' : floatToLocalString(value));
    return value + unit;
}

function convertSec(value) {
    var unit = '';
    var decsep = getLocalDecimalSeparator();
    
    if(value < 1e-6) {
        value *= 1e9;
        unit = '<span class="unit">ns</span>';
    }
    else if(value < 1e-3) {
        value *= 1e6;
        unit = '<span class="unit">μs</span>';
    }
    else if(value < 1) {
        value *= 1e3
        unit = '<span class="unit">ms</span>';
    }
    else {
        unit = '<span class="unit">s</span>';
    }

    // Fix to 4 decimal digits in total regardless of the decimal point placement
    var eps = 1e-2;
    if (value >= 100 - eps) {
        value = value.toFixed(1);
    }
    else if  (value >= 10 - eps) {
        value = value.toFixed(2);
    }
    else {
        value = value.toFixed(3);
    }
    
    value = (value == 0 ? '---' + decsep + '-' : floatToLocalString(value));
    return value + unit;
}

function storeDigdarParams() {
    $.post(
        store_params_url, 
        JSON.stringify(params.local)
    );
}

function loadDigdarParams() {
    $.get(
        load_params_url,
        function(data) {
            params.local = JSON.parse(data);
        }
    );
}

function loadDigdarFactoryParams() {
    $.get(
        load_factory_params_url,
        function(data) {
            params.local = JSON.parse(data);
        }
    );
}
