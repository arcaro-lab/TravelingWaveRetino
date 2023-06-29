% ver 1, port of J Swisher's Vision Egg code (Swisher et al. 2007,JNeuro), ma 07/17/09
% modified (pure) log scaling of eccentricity, switched timing from frame rate to actual time, converted to function c said 09/20/09
% added cortical mag. function from Swisher et al. 2007 (ala Duncan and Boynton, 2002), ma 08/10/10
% added default value structure, use of paramters wrapper file, ability to do
% multiple runs, save behav data, ma 12/03/10
%
% 05.2011 - REHBM - added a secondary angle for target that is randomized after each target is turned off to avoid
%                   a consistency of the target angle with eccentricity (especially in eccentricity mapping)
%                 - various minor updates
%                 - added moving dot stimulus option
%                 - _test2.m, changed dots to be confined to (and to always fill) the entire viewable screen to decrease the number of dots to track/upate that are not possibly visible.  need to cut down on ndots for efficiency sake
%                 - _test3.m, added discrete steps (normal and random) transitions
%                 - _test4.m, variable name updating to make them more general
%                             changed the format of the datafile and how behavior is saved
%                 - _test5.m, integrated the code controlling transitions of 'discrete_steps' and 'discrete_random'. now called 'discrete' and order controlled by options.discrete.order = 'steps', 'random' or vector containing 1:ncycles*steps_per_cycle defining index of cycle-step pairs to transition through
%                             added ability to take screen shots at any arbitrary time within a run and save out the files.
%                             added targ_allow variable for added control over target appearance (eg, disallow close to discrete mask changed)
% 09.06.11        - removed _testX.m suffix

function [] = TravelingWave(options)

try

    %% init
    %clear mex;
    
    AssertOpenGL;
    rand('state',sum(100*clock));
    PsychJavaTrouble;
    if IsOSX
        Priority(9); % safe to set to highest Priority on Mac OSX
    elseif IsWin
        Priority(1); % 2 is highest, but will lock out keyboard interupts.  probably not going to be run on Windows anyway...
    end
    
    
    %% Default Paramters
    % default parameters can be changed through the p structure input.  For example:
    %    p.subj = 'test';
    %    p.stimulus = 'checker';
    %    p.direction = {'cw'};
    %    retinotopy(p);
    % will execute this code with a checkboard stimulus and a clock-wise rotating wedge mask and save the file with the subject prefix of 'test'
    
    % Datafile --------------------------------
    defaults.subj               =   '__TEST__';
    curclock = clock;
    defaults.date               =   datestr(curclock,'mmddyy');
    defaults.time               =   datestr(curclock,'HHMMSS');
    defaults.savefile           =   1; % boolean, should we save a datafile?
    
    
    % Screen and Display --------------------------------
    % change to match your scanner situation.
    defaults.screen_w           =   39;         % screen width, 39 @ scanner (cm), 50 w/ LCD
    defaults.screen_d           =   60;         % screen viewing distance (cm)
    defaults.bg_color           =   [0 0 0];    % background color on 0-255 [R G B] scale
    defaults.screenshot_times   =   [];         % vector of times (sec, relative to start of run) at which to take a screen shot of the completely drawn stimulus and mask (without fixation spot). If nrows is 1, then same times are used for all runs.  else, each row is run-specific times. If not empty, stimulus will be forced to 'white' and 'bg_color' to black so that screen shots are boolean masks of stimulus coverage.  'savefile' is set to 0.
    defaults.screenshot_format  =   'matlab';   % 'matlab' or 'm' to save as an m-file (non-ascii as ascii files are very large comparatively), or any image format accepted by IMWRITE to save as images
    
    
    % Response --------------------------------
    % use 'key' structure for easy passing to CheckButtonResponse
    defaults.key.dev_id             =   -1;         % device id for checking responses.  -1 for all devices (but might be slow and miss some responses)
    defaults.key.quit_key           =   20;         % Q for quit
    defaults.key.resp_key           =   44;         % response button, 44 for Keyboard, 33 for button box
        
    
    % Timing ----------------------------------------------------
    defaults.ncycles            =   8;          % number of cycles
    defaults.cycle_duration     =   40;         % duration (sec) of a single cycle (eg, rotation period of wedge or ring). *** should be an increment of the TR ***
    defaults.init_blank_time    =   0;          % initial blank time (sec)
    defaults.end_blank_time     =   0;          % blank time at end (sec)
        
    
    % Fixation Point ----------------------------------------------------
    defaults.fix.color          =   [255 255 255]; % color of fixation spot
    defaults.fix.dim_color      =   [100 100 100]; % color of fixation spot for fixation-dimming events (see defaults.attend_task)
    defaults.fix.size           =   4;             % radius in pixels, of fixation point
    defaults.fix.size_inner     =   2;             % radius in pixels, of an inner square of fixation point, same color as bg_color.  zero for solid square fixation spot as defined by fix.size and fix.color.

    
    
    % Stimulus ----------------------------------------------------
    % stimuli are displayed full-screen.  'mask' defines how much and which part of the stimulus is visible at any point in time.
    defaults.stimulus  = 'checker'; % type of visual stimulus.  'checkerboard', 'dots', or 'white'

    % options for checkerboard stimulus
    defaults.checker.image_size         = 'full_screen';        % size (deg radius) of background checkerboard image or 'full_screen' to fill screen with image.  Leave at 'full_screen' if unsure, better to scale mask directly.
    defaults.checker.color_checker      =   1;          % 0 for B&W, 1 for color
    defaults.checker.flicker_freq       =   4;          % flicker frequency for full black-white cycle (hz)
    defaults.checker.flickstim          =   0;          % Flicker Stimulus 0 for checkerboard, 1 for black
    defaults.checker.checker_rot        =   0;          % rotation period of background checkboard (only); 0 for no rotation; >0 for cw, <0 for ccw. *** keep to 0 if unsure ***
    
    % moving dots
    defaults.dots.n 	= 13000;	     % number of dots
    defaults.dots.speed = 7;	         % normal dot speed (deg/sec)
    defaults.dots.size  = 6;             % dot width (pixels)
    defaults.dots.color = [255 255 255]'; % vector [R G B] color of each dot.  Can define color separately for each dot in an 3xNDOTS matrix.
    defaults.dots.fcoh  = 0.50;	         % fraction of coherent dots moving in same direction.  these dots change direction for peripheral target when using dots stimuli.
    defaults.dots.fkill = 0.01; 	     % fraction of dots to kill each frame (to avoid subject being able to track a single dot for peripheral task)
    
    
    % Attention Task ----------------------------------------------------
    defaults.attend_task          =   2;             % 1 for fixation dimming task, 2 for peripheral (ring/wedge/dots)
    defaults.min_targ             =   2;             % minimum time (sec) between target events
    defaults.max_targ             =   5;             % maximum time (sec) between target events

    defaults.dim_value            =   [137 137 137 255]; % dim color (0-255 [R G B]) for checkerboard attention task
    defaults.dim_length           =   0.08;          % duration (sec) of fixation and checkerboard dimming events
    defaults.attend_checker_ring  =   3;          % atten ring duty cycle (width) for wedge mask
    defaults.attend_checker_wedge =   30;         % degress of atten wedge size for ring mask
    defaults.attend_checker_bar   =   3;          % width (deg) of atten bar size for bar mask
% %     defaults.attend_dots_type     =   'direction'; % 
    defaults.attend_dots_mdir     =   [75 105];   % range [min max] of angular directional (deg) change in coherent dot motion for peripheral target
% %     defaults.attend_dots_speed    =   1;   % amplitude of speed (pix/sec) change (randomly +/-) in all dot motion for peripheral target
    
    
    % Mask ----------------------------------------------------
    % General - shared across all masks
    % N.B. the mask type is inherently defined by the direction
    defaults.duty                 = 0.125;   % duty cycle (0.125 = 12.5%): fraction of cycle time that stimulus is visible at any one point.  For wedge, angular size is 360 * duty.
    defaults.direction            = {};        % cell array of strings, one for each run.  options are wedge:'cw','ccw'     ring:'in','out'     bar:'bar'
    defaults.transition           = 'smooth';  % 'smooth' for continuous updating of position and smoothly moving mask, 'discrete' for for static mask positions changes (see defaults.discrete.order)

    % additional options for discrete transitions
    defaults.discrete.order       = 'straight'; % defines the order of cycling through all possible cycle-step pairs.  'straight' (default) for straight progression, 'random' for random order, or vector containing values 1:(ncycles*steps_per_cycle) defining index of cycle-step pairs to move through
    defaults.discrete.step_size   = 'calculate'; % (sec) if discrete.step_size is true, how long does the mask stay in one position?  in other words, at what time is the mask updated to step to the next position?  if 'calculate' the discrete.step_size will be calculated such that each point on the screen is part of one and only one step
    defaults.discrete.step_offset = 'half_step_size'; % time offset (sec) to shift each discrete step by.  If 0, the first step will not show a simulus (or rather a sliver of one).  By default, it is 'half_step_size', which will be calculated as discrete.step_size/2.
    
    % Rotating Wedge - standard polar angle mapping - ('cw' or 'ccw')
    defaults.wedge.cut_out     =   0;          % cut out n deg (radius) from center. set to zero for no cut_out.
    defaults.wedge.cut_in      =   15;         % cut in n deg (radius) from outer max; defines extent (max eccen) of wedge
    defaults.wedge.start_angle =   90;         % where center of wedge starts at time zero (deg). 0 up, positive is clock-wise, 90 (default) is right horizontal meridian 
    
    % Ring Properties - standard eccentricity mapping - ('in' or 'out')
    defaults.ring.outer_deg_max =   15;         % outer maximum stimulation point for ring
    defaults.ring.inner_deg_min =   0;          % inner minimum stimulation point for ring (must be >=0)
    defaults.ring.scaling       =   1;          % 1 for linear, 2 for pure logarithmic, 3 log-based cortical magnification ala Boynton & Duncan, 2002

    % Bar Properties - PRF mapping - ('bar', but note that bar.angles is needed to define specific bar directions)
    defaults.bar.angles        =   (0:(360/defaults.ncycles):(360-360/defaults.ncycles));  % bar.angles defines the starting position of the bars center. 0 up, positive clockwise.  use NaN for fixation-only (no stimulus, null) cycles.  bars move perpendicular to the bar.angles vectors.  size(bar.angles,2) must equal ncycles. Number of rows (size(bar.angles,1)) should be 1 (to use the same angle progression for all runs), or length(direction) to use a unique angle progression for each run.
    defaults.bar.outer_deg_max =   15;         % outer maximum stimulation point for bar (N.B. we are hijacking the ring code, so you can think of bar max as being tanjential to ring max)
    defaults.bar.inner_deg_min =   -defaults.bar.outer_deg_max; % inner minimum stimulation point for bar (N.B. we are hijacking the ring code, so you can think of bar min as being tanjential to ring min)
    defaults.bar.cut_out       =   0.5;        % cut out n deg (radius) from center. set to zero for no cut_out. might be useful to keep stimulus off of fixation spot
    defaults.bar.cut_in        =   defaults.bar.outer_deg_max;        % cut in n deg (radius) from outer max; equals max eccen of wedge.  set to NaN for no cut_in.
    defaults.bar.scaling       =   1;          % 1 for linear, 2 for pure logarithmic, 3 log-based cortical magnification ala Boynton & Duncan, 2002

    
    % Blanks ----------------------------------------------------
    % Use these parameters to create arbitrarily timed blank periods.
    defaults.blanks = []; % Nx3 element matrix (e.g., [3 0.5 1; 4 0.33 0.66] where each row-triplet defines a blank period.  The 1st column is the cycle during which the blank occurs and the 2nd and 3rd columns defined when the blank starts and stops, respectively, in time_fraction units.  A full cycle goes from 0-1. In the example given, there would be no stimulus during the 2nd half of the 3rd cycle and the middle 3rd of the 4th cycle.
   
    
    % Extras ----------------------------------------------------
    defaults.debugging         = 0; % if true, will not HideCursor or ListenChar(2) and will keep track of the duration of each frame
    
    
    
    %% Merge Defaults and Options
    % merge input arguments (options) with defaults (defaults)
    fns = fieldnames(defaults);
    % merge sub structure first...
    for i = 1:length(fns)
        this_fn = fns{i};
        if isstruct(defaults.(this_fn)) && isfield(options,this_fn)
            options.(this_fn) = propval(options.(this_fn),defaults.(this_fn));
        end
    end
    options = propval(options,defaults);
    
    % update parameters after merging defaults with options
    if strcmp(options.discrete.step_size,'calculate')
        options.discrete.step_size = options.cycle_duration * options.duty;
    end
    if strcmp(options.discrete.step_offset,'half_step_size')
        options.discrete.step_offset = options.discrete.step_size/2;
    end    
    
    % define variables for all of the option fields so that we can refer to them
    % without the option. strucutre.  just to keep the code below cleaner....
    fns = fieldnames(options);
    for i = 1:length(fns)
        this_fn = fns{i}; % string
        eval(sprintf('%s = options.%s;',this_fn,this_fn));
    end
    
    
    %% validate arguments
    % in no particular order...
    if ~isfield(options,'direction')
        error('Please define at least one direction');
    end
    if ischar(options.direction)
        options.direction = {options.direction}; % force user to define direction (ie, no default)
    end
    dir_check = ~ismember(options.direction,{'cw'; 'ccw'; 'in'; 'out'; 'bar'});
    if any(dir_check)
        error(['Invalid experiment type (options.direction) for run(s) ' mat2str(find(dir_check)) '. Must be ''cw'', ''ccw'', ''in'', ''out'', ''bar''.']);
    end
    
    if options.fix.size_inner >= options.fix.size
        error('fix.size_inner must be smaller than fix.size')
    end

    if options.ring.inner_deg_min < 0
        error('ring.inner_deg_min must be >= 0')
    end
    
    % blanks
    if isempty(options.blanks)
        % setup an empty blanks matrix
        blanks = [NaN NaN NaN]; % no blanks defined
    else
        % validate structure of input
        if size(options.blanks,2)~=3
            error('blanks must be a 3-column matrix')
        end
        if any(options.blanks(:,1)<1) || any(mod(options.blanks(:,1),1)) || any(options.blanks(:,1)>ncycles)
            error('the first column of blanks (cycle) must be an integer between 1 and ncycles (%d)',ncycles)
        end
        if any(any(options.blanks(:,[2 3])<0)) || any(any(options.blanks(:,[2 3])>1))
            error('the second and third columns of blanks define the start and stop time fractions and must be between 0 and 1')
        end
    end

    
    
    %% Local Variables
    % ...that can be determined now that options have been fully parsed ---
    if strcmp(transition,'discrete')
        % create a list of all possible cycle-step pairs to be shown across entire run
        steps_per_cycle = options.cycle_duration/discrete.step_size;
        [tmp_c tmp_s]   = meshgrid(1:ncycles,1:steps_per_cycle);
        cycle_steps     = [tmp_c(:) tmp_s(:)]; % all possible cycle-step pairs
                
        % create index for how to move through all possible cycle-step pairs
        straight_idx = 1:size(cycle_steps,1);
        if ischar(discrete.order)
            switch discrete.order
                case 'straight'
                    % setup to progress through cycle-step pairs in normal order
                    options.discrete.order = straight_idx; % save to options structure so that the EXACT order is saved in the output file and can be easily reloaded later
                case 'random'
                    % generate random index
                    options.discrete.order = shuffle(straight_idx); % save to options structure so that the EXACT order is saved in the output file and can be easily reloaded later
                otherwise
                    error('discrete.order must be ''straight'', ''random'' or a numeric vector containing the values 1:length(ncycles*steps_per_cycle) [%d*%d=%d for current options].',ncycles,steps_per_cycle,ncycles*steps_per_cycle)
            end
        elseif ~issame(sort(options.discrete.order),straight_idx)
            % then we should have a vector that defines the order.  make sure it is a valid vector...
            error('discrete.order must be ''straight'', ''random'' or a numeric vector containing the values 1:length(ncycles*steps_per_cycle) [%d*%d=%d for current options].',ncycles,steps_per_cycle,ncycles*steps_per_cycle)
        end
        
        % reorder cycle_steps to match the required order
        cycle_steps = cycle_steps(options.discrete.order,:);
    end

    % bar angles
    if strcmp(direction,'bar')
        if size(bar.angles,2) ~= ncycles
            error('for bar mask, number of columns in bar.angles (which define the direction of each cycle) must be the same length as the number of cycles')
        end
        if size(bar.angles,1) == 1
            bar.angles = repmat(bar.angles,length(direction),1);
        elseif size(bar.angles,1) ~= length(direction)
            error('for bar mask, number of rows in bar.angles (which define the angle progression for each run) must be 1 or length(direction)')
        end
    end
    
    % for screenshots
    if ~isempty(screenshot_times)
        % override 'stimulus' and 'bg_color' and 'savefile'
        options.savefile = 0;
        options.stimulus = 'white';
        options.bg_color = [0 0 0]; % black
        if size(screenshot_times,1) == 1
            screenshot_times = repmat(screenshot_times,length(direction),1);
        elseif ~isempty(screenshot_times) && size(screenshot_times,1) ~= length(direction)
            error('when taking screenshots, number of rows in screenshot_times (which define the run-relative times of successive screenshots for each run) must be 1 or length(direction)')
        end
    end
    
    % dots
    if isvector(dots.color) && size(dots.color,2) == 3 % identify row vector
        dots.color = dots.color';
    end
    
    %Create filename to save data: Subj_date_time
    filename = sprintf('%s_%s_%s_%s',options.subj, mfilename, options.date, options.time);
    
    
       
    %% PTB Screen Setup
    screens      = (Screen('Screens'));
    screenNumber = max(screens);                % should equal 1 if using my office Mac
    [w, rect]    = Screen('OpenWindow', screenNumber);
    Screen('FillRect',w, [0 150 150]); % change background color so we know that things are loading properly
    Screen('Flip', w,0,1);

    % Enable alpha blending for contrast manipulations (for drawing circular dots)
    Screen('BlendFunction', w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    % Calculate frame rate
    frate = Screen('FrameRate',w);                % get frame rate from 'FrameRate'
    ifi = Screen('GetFlipInterval', w);
    if frate == 0                                 % if FrameRate returns 0....
        frate = 1/ifi;                            % get frame rate from GetFlipINterval
    end;
    
    white_index = WhiteIndex(w);                  % set white RGB values
    black_index = BlackIndex(w);                  % set black RGB values
    
    % some useful screen measurements and markers
    xc = rect(3)/2;                               % calculate central point on x-axis
    yc = rect(4)/2;                               % calculate central point on y-axis
    corner_radius   = floor(sqrt((yc^2)+(xc^2))); % maximum screen radius in pixels (center-to-corner)      % OLD DEFINITION: floor(sqrt((rect(4)^2)+(rect(3)^2)));
    cardinal_radius = max([xc yc]);               % maximum screen radius along the cardinal (x and y) axes (ie, which is longer, x or y?)

    % some common drawing rects for PTB functions
    fix.rect        = [xc-fix.size; yc-fix.size; xc+fix.size; yc+fix.size]; % PTB rect for drawing fixation spot
    fix.rect_inner  = [xc-fix.size_inner; yc-fix.size_inner; xc+fix.size_inner; yc+fix.size_inner]; % PTB rect for drawing fixation spot
    fix.bg_color = bg_color; % so we can pass bg_color with fix structure to add_fixspot
    corner_rect     = [xc-corner_radius yc-corner_radius xc+corner_radius yc+corner_radius]; % PTB rect size of corner_radius
    cardinal_rect   = [xc-cardinal_radius yc-cardinal_radius xc+cardinal_radius yc+cardinal_radius]; % PTB rect size of cardinal_radius
    
    
    % Calculate pixels per degree (ppd).
    ppd = rect(3)/(2*atan(screen_w/(screen_d*2))*180/pi);
    
    
    % Convert from ppd into pixels
    wedge.cut_out      = round(wedge.cut_out*ppd);
    wedge.cut_in       = round(wedge.cut_in*ppd);
    bar.cut_out        = round(bar.cut_out*ppd);
    bar.cut_in         = round(bar.cut_in*ppd);
    attend_checker_ring = attend_checker_ring*ppd;
   
    
    % Setup up stim timing variables
    total_time = init_blank_time + cycle_duration * ncycles + end_blank_time;
    flick_dur  = 1/checker.flicker_freq/2;
    
    
    
    %% Setup Stimulus
    % ie, the stuff behind the moving mask...
    switch stimulus
        case 'checker' % flashing/alternating checkerboard images
            % Read in background images
            if checker.color_checker == 1
                checker1 = imread('./images/background0.png');
                checker2 = imread('./images/background1.png');
            elseif color_checker == 0
                checker1 = imread('./images/background_bw_0.png');
                checker2 = imread('./images/background_bw_1.png');
            end
            
            % ???
            if checker.flickstim
                checker1 = checker1./checker1;
            end
            
            
            % ??? is there a reason we can't just resize when we draw it using DrawTexture?  is that too slow?
            % Resize images
            if strcmp(checker.image_size,'full_screen')
                image_size = max([xc yc]) / ppd; % deg
            end
            ImageSize   = image_size * 2 * ppd;
    
            imgscale = ImageSize/length(checker1);
            checker1 = imresize(checker1,imgscale);
            checker2 = imresize(checker2,imgscale);
                        
            checker_tex(1) = Screen('MakeTexture', w, checker1);
            checker_tex(2) = Screen('MakeTexture', w, checker2);
           
        case 'scenes'            % flashing scene images?
            error('scene stimuli haven''t been fully ported to the new code base yet...')
            %     if stim == 2
            %         bkimage1  = imread('./images/Scene_06.jpg');
            %         bkimage2  = imread('./images/Scene_07.jpg');
            %         bkimage3  = imread('./images/Scene_11.jpg');
            %         bkimage4  = imread('./images/Scene_12.jpg');
            %         bkimage5  = imread('./images/Scene_14.jpg');
            %         bkimage6  = imread('./images/Scene_18.jpg');
            %         bkimage7  = imread('./images/Scene_25.jpg');
            %         bkimage8  = imread('./images/Scene_28.jpg');
            %         bkimage9  = imread('./images/Scene_35.jpg');
            %         bkimage10 = imread('./images/Scene_38.jpg');
            %         bkimage11 = imread('./images/Scene_40.jpg');
            %     end
           
            %     % Resize images
            %     ImageSize = StimSize*ppd;
            %
            %     imgscale = ImageSize/length(checker1);
 
    
            %     if stim == 2
            %         imgscale  = ImageSize/length(bkimage1);
            %         bkimage1  = imresize(bkimage1,imgscale);
            %         bkimage2  = imresize(bkimage2,imgscale);
            %         bkimage3  = imresize(bkimage3,imgscale);
            %         bkimage4  = imresize(bkimage4,imgscale);
            %         bkimage5  = imresize(bkimage5,imgscale);
            %         bkimage6  = imresize(bkimage6,imgscale);
            %         bkimage7  = imresize(bkimage7,imgscale);
            %         bkimage8  = imresize(bkimage8,imgscale);
            %         bkimage9  = imresize(bkimage9,imgscale);
            %         bkimage10 = imresize(bkimage10,imgscale);
            %         bkimage11 = imresize(bkimage11,imgscale);
            %
            %     end
            
            
            
            %     if stim == 2
            %         bkimage_tex(1)  = Screen('MakeTexture', w, bkimage1);
            %         bkimage_tex(2)  = Screen('MakeTexture', w, bkimage2);
            %         bkimage_tex(3)  = Screen('MakeTexture', w, bkimage3);
            %         bkimage_tex(4)  = Screen('MakeTexture', w, bkimage4);
            %         bkimage_tex(5)  = Screen('MakeTexture', w, bkimage5);
            %         bkimage_tex(6)  = Screen('MakeTexture', w, bkimage6);
            %         bkimage_tex(7)  = Screen('MakeTexture', w, bkimage7);
            %         bkimage_tex(8)  = Screen('MakeTexture', w, bkimage8);
            %         bkimage_tex(9)  = Screen('MakeTexture', w, bkimage9);
            %         bkimage_tex(10) = Screen('MakeTexture', w, bkimage10);
            %         bkimage_tex(11) = Screen('MakeTexture', w, bkimage11);
            %
            %     end
            
        case 'dots' % random dot motion
            % %             % expand to be fully explicit (in case the peripheral dot task is dimming)
            % %             dots.color      = repmat(dots.color,1,dots.n);
            % %             dots.orig_color = dots.color; % remember initial value for resetting after dim
            
            % convert speed from deg/sec to pix/sec
            dots_speed_orig = dots.speed;
            dots.speed_pps = dots_speed_orig * ppd; % normal dot speed (pix/sec)
        
        case 'white' % solid white background
            % nothing to do.  this options is mostly here for taking pRF-appropriate screen shots of stimulus coverage after mask is applied
            
        otherwise
            error('invalid stimulus (%s)',stimulus)
    end
    
    
    %% Setup Mask
    % the mask is direction-dependent and defines what is shown at any point in time
    if any(ismember(direction,{'cw' 'ccw'})) % if any of the requested runs will use the wedge mask...
        wedge_size = duty * 360; % angular spread of wedge is the fraction of full circle visible as defined by duty cycle
    end
    if any(ismember(direction,{'in' 'out'})) % if any of the requested runs will use the ring mask...
    end
    if any(ismember(direction,'bar')) % if any of the requested runs will use the bar mask...
        % make box texture for masking non-visible stimuli - textures are the easiest thing to place in an arbitrary coordinate with an arbitrary rotation
        bar_mask       = repmat(reshape(bg_color,[1 1 3]),[128 128 1]); % 128 x128x3 image of a bg_color rectangle
        bar_mask_texid = Screen('MakeTexture',w,bar_mask,[],1);
        bar_mask_rect = corner_rect; % central template for mask's drawing rect
        
        % make box texture for potential targets (dims) with checkerboard stimulus
        bar_dim       = repmat(reshape(dim_value,[1 1 3]),[128 128 1]); % 128 x128x3 image of a dim_value rectangle
        bar_dim_texid = Screen('MakeTexture',w,bar_dim,[],1);
        bar_dim_width = attend_checker_bar * ppd;
        bar_dim_rect  = [xc-bar_dim_width/2 yc-corner_radius xc+bar_dim_width/2 yc+corner_radius]; % bar that will be orthogonal to bar mask
        
        % for bar stimulus, we need to choose a random x-coordinate, which, after rotation
        % will be along the bar's axis.  start by defining the max displacement allowed and
        % choosing a random x position for first (potential) peripheral target
        bar_dim_maxrho = min([xc yc bar.cut_in]) - bar_dim_width/2; % maximum visible displacement along bar axis
        bar_dim_rho    = 2*(rand-0.5) * bar_dim_maxrho; % random displacement along bar axis
    end
    
    
    %% setup behav structure for storing and saving behavioral data
    nRuns = length(options.direction);
    behav.runtime      = repmat(NaN,1,nRuns);
    behav.accuracy     = repmat(NaN,1,nRuns);
    behav.hits         = repmat(0,1,nRuns);
    behav.false_alarms = repmat(0,1,nRuns);
    behav.total_targs  = repmat(0,1,nRuns);
    

    %% Loop Over Runs
    for currun = 1:nRuns;
        if ~debugging
            HideCursor;                         % Hide the mouse cursor
            ListenChar(2);
        else
            % some extra stuff to track
            loop_count = 0;
            loop_n = 1000; % how many loops to track duration for?
            loop_dur  = repmat(NaN,loop_n,1);
        end
        
        % Initialize variables that get reset at begining of each run
        fix.current_color       = fix.color; % start with undimmed color
        targ_allow              = 1; % by default, target is always allowed (can occur at any time)
        targ_on                 = 0;
        this_behav.accuracy     = NaN;
        this_behav.hits         = 0;
        this_behav.false_alarms = 0;
        this_behav.total_targs  = 0;
        flicker_type            = 1;
        %count                   = 1;
        timing.check_target     = 0;
        timing.check_prior      = 0;
        key.quit                = 0;
        checker_angle           = 0;
        timing.start_resp_time  = [];
        timing.resp_interval    = 1;  %Time alloted for correct response (in seconds)
        last_cycle              = 0; % init for variables that change only during cycle change
        last_step               = 0; % for (potentially used) discrete steps in mask position (through time_frac updating)

        
        % Initialize Functions
        [keyIsDown, secs, keycode] = KbCheck(key.dev_id);   % check response
        CheckButtonResponse(timing, key, this_behav);
        time_frac = 0;
        get_ring_edges(ring.outer_deg_max, ring.inner_deg_min, time_frac, duty);
        

        % Display 'Wait for scanner to start' screen
        Screen('FillRect',w, bg_color); % fill background
        add_fixspot(w,fix); % fixation spot
        txt = 'Wait for experiment to start';                                                  % define text
        txtloc = [xc - length(txt) * 14 / 2, yc + 40];                                         % define text location
        Screen('TextSize', w, 25);                                                             % set text size
        [newX newY] = Screen('DrawText',w,txt,txtloc(1),txtloc(2),white_index);                % draw text
        Screen('Flip',w,[],1);
        
        
        % setup stimulus
        switch stimulus
            case 'checker' % checker board stimulus
                current_stim = checker_tex;
            
            case 'scenes' % scene images
                error('scene stimuli haven''t been fully ported to the new code base yet...')
                %current_stim = [shuffle(bkimage_tex),shuffle(bkimage_tex),shuffle(bkimage_tex),shuffle(bkimage_tex),shuffle(bkimage_tex),shuffle(bkimage_tex),shuffle(bkimage_tex)];

            case 'dots' % random dot motion
                % set up initial dot positions/motion directions/velocities
                xy = [2*xc*rand(dots.n,1)-xc 2*yc*rand(dots.n,1)-yc]; % dot starting positions, bounded by screen (pixels)
                                
                mdir = 2*pi*rand(dots.n,1);	% angular motion direction for each dot
                coh = rand(dots.n,1) < dots.fcoh;	% the coherently moving dots
                cohdir = 2*pi*rand; % defined randomly here.  for bar stim this will be updated depending on bar direction
                mdir(coh) = cohdir; 	% direction of coherent motion;
                last_dtime = 0; % time (relative to start of run) since last update of dot position
                
            case 'white' % solid white background
                % nothing to do
                
            otherwise
                error('sorry, don''t know how to update stimulus of type %s',stimulus)
        end
        
        
        % setup for mask
        if strcmp(direction(currun),'bar')
            run_bar_angles = bar.angles(currun,:);
        end

        
        % setup for screenshots
        if ~isempty(screenshot_times)
            run_screenshot_times = screenshot_times(currun,:);
            screenshot_idx = 0;
            take_screenshots = 1;
        else
            take_screenshots = 0;
        end
        
        
        % wait for trigger (or button response) to start experiment (but don't wait if we are just taking screenshots)
        while ~keyIsDown && ~take_screenshots
            [keyIsDown, secs, keycode] = KbCheck(key.dev_id); %check response
            if keycode(key.quit_key)
                key.quit = 1;
            end
            if keycode(key.resp_key)
                % don't let subject accidentily start next run with response button
                keyIsDown = 0;
            end
        end
        
        
        %% Start This Run
        % clear screen to fixspot
        Screen('FillRect',w,bg_color); % fill background
        add_fixspot(w,fix); % fixation spot
        Screen('Flip', w);
        
        % Wait for initial blank time
        start_init_blank = GetSecs;
        while GetSecs - start_init_blank < init_blank_time
            WaitSecs(0.001); % avoid CPU hogging
        end
        
        
        %Timing Variables that get reset at begining of each run
        start_time      = GetSecs; % note that start_time excludes init_blank_time
        flicker_time    = start_time + flick_dur; % next time we should flicker the stimulus
        timing.next_fix = start_time + min_targ + (max_targ-min_targ).*rand; % next time there should be a target (fixdim or peripheral target)

        if debugging
            tic; % for loop duration tracking
        end
        
        % Cycle Loop
        while(GetSecs-start_time < ncycles * cycle_duration) && ~key.quit
            
            %% update timing variables
            if take_screenshots
                % force time to next requested screenshot time
                screenshot_idx = screenshot_idx+1;
                cur_time = run_screenshot_times(screenshot_idx);
                if screenshot_idx == length(run_screenshot_times)
                    % then this is the last screenshot of this run, exit after this "frame"
                    key.quit = 1; % to stop the run loop
                end
            else
                cur_time = GetSecs - start_time; % current time relative to start of run
            end
            cur_cycle = floor(cur_time/cycle_duration)+1;
            switch transition
                case 'smooth'
                    % continuous updating on each frame
                    time_frac = mod(cur_time, cycle_duration)/cycle_duration; % fraction of cycle we've gone through
                    abs_time_frac = time_frac; % for timing relative to time_frac, independent of directions that require "time-reversals"
                    if any(strcmp(options.direction(currun), {'ccw', 'in', 'bar'}))
                        time_frac = 1-time_frac; % reversing time for these conditions
                    end
                case 'discrete'
                    % only update time_frac variable (which controls mask position) in discrete steps
                    cur_cyctime = cur_time-(cur_cycle-1)*cycle_duration; % time relative to start of current cycle
                    cur_steptime = mod(cur_time,discrete.step_size);     % time relativet to start of current step
                    cur_step = floor(cur_cyctime/discrete.step_size)+1;  % step number, relative to the current cycle

                    % disallow target appearance at the very beginning (first 20%) and very end of (last 80%) discrete step changes
                    if cur_steptime < 0.20 || cur_steptime > 0.80 % hardcoded as 20-80% of step time when target is allowed. could incorporate into options.
                        %fprintf('disallow target...\n')
                        targ_allow = 0;
                    else
                        targ_allow = 1;
                    end
                    
                    % convert cur_step into cycle-step index (relative to run start)
                    cur_cycstep_idx = cur_step + (cur_cycle-1) * steps_per_cycle;

                    % pull cur_cycle and cur_step from pre-ordered cycle-steps pairs (cycle_steps)
                    cur_cycle = cycle_steps(cur_cycstep_idx,1);
                    cur_step  = cycle_steps(cur_cycstep_idx,2);
                    
                    if cur_step ~= last_step
                        % then this is a new step so update time_frac
                        % N.B. we need to update time_frac DIRECTLY to force it to the proper step within the desired cycle
                        %      to account for potenial non-straight order of cycle-step pairs
                        time_frac = (cur_step-1)/steps_per_cycle;
                        time_frac = time_frac + discrete.step_offset/cycle_duration; % add offset for discrete mask changes
                        abs_time_frac = time_frac; % for timing relative to time_frac, independent of directions that require "time-reversals"
                        if any(strcmp(options.direction(currun), {'ccw', 'in', 'bar'}))
                            time_frac = 1-time_frac;                                            % reversing time for these conditions
                        end
                        last_step = cur_step;
                    end
                    
                otherwise
                    error('invalid transition type supplied')
            end
            
            
            % determine if we are in a "blank" period and we should be masking entire stimulus
            isblank = 0; % by default, assume it isn't a blank period
            if any(and(blanks(:,1)==cur_cycle, and(abs_time_frac>=blanks(:,2),abs_time_frac<=blanks(:,3))))
                % there is a blank for the current cycle during the current time fraction (absolute, without time-reversal for some direction)
                isblank = 1;
            end
            
            
            % % % some useful debugging code, but note that writing to command window every loop cycle will disrupt timing of stimulus (drasticaly in the case of the dots)
            % % cur_cyctime = cur_time-(cur_cycle-1)*cycle_duration; % time relative to start of current cycle
            % % cur_step = floor(cur_cyctime/2)+1;
            % % fprintf('%.02f\t%d\t%.02f\t%d\t%d\n',cur_time,cur_cycle,cur_cyctime,cur_step,cur_cycstep_idx)
            
            
            % update variables that change depending on cycle, but are constant within a given cycle
            if cur_cycle ~= last_cycle
                % we've entered the next cycle
                if strcmp(direction{currun},'bar') % BAR stim/mask
                    % update bar angle for next cycle
                    this_bar_angle_deg = run_bar_angles(cur_cycle);

                    if strcmp(stimulus,'dots') && ~isnan(this_bar_angle_deg) % random dot motion (and bar stimulus)
                        % for dot motion with bar stimulus, direction always moves along bars main axis.
                        % update with each new cycle since bar direction will probably change (ignore for NaN too)
                        
                        % N.B. this_bar_angle_deg and Matlab's polar coordinate systems are offset by 90 deg.  but we
                        %      also need our dot motion direction offset by 90 deg from this_bar_angle_deg.  This is
                        %      inherent in the direct conversion of this_bar_angle_deg to radians (+ 50% chance of 180 deg flip)
                        cohdir = this_bar_angle_deg * pi/180 + round(rand)*pi;
                    end
                end
                last_cycle = cur_cycle; % udpate last_cycle so we only enter this once/cycle
            end
            
            
            %% update mask-related variables
            switch direction{currun}
                case {'cw' 'ccw'}
                    % Calculate current angle of wedge (and potential target) based on run time
                    stim_angle = (pi + (2*pi*time_frac - pi))*(180/pi)+wedge.start_angle;
                    
                case {'out' 'in'}
                    switch ring.scaling
                        case 1 % linear scaling
                            [r_outer_deg r_inner_deg] = get_ring_edges(ring.outer_deg_max, ring.inner_deg_min, time_frac, duty);
                            
                        case 2 % log scaling
                            %First convert visual angle range to cortical distance range, only considering RF centers%
                            r_outer_ctx_max = log(ring.outer_deg_max+1);                           % maximum stimulation distance from foveal representation in cortex, in mm, only considering RF centers
                            r_inner_ctx_min = log(ring.inner_deg_min+1);
                            
                            %Then allow traveling wave to move linearly across cortex, only
                            %considering RF centers.
                            [r_outer_ctx r_inner_ctx] = get_ring_edges(r_outer_ctx_max, r_inner_ctx_min, time_frac, duty);
                            
                            %then convert back to visual angle. Duty cycle is preserved.%
                            r_outer_deg = exp(r_outer_ctx) - 1;
                            r_inner_deg = exp(r_inner_ctx) - 1;
                            
                        case 3 % cortical mag scalind
                            self.nrp_C  = ((ring.outer_deg_max))/(exp(2.5)-1); % scaling constant for cortical mag.
                            
                            r_outer_ctx_max = (log((ring.outer_deg_max/self.nrp_C)+1))/2.5;        % maximum stimulation distance from foveal representation in cortex, in mm, only considering RF centers
                            r_inner_ctx_min = (log((ring.inner_deg_min/self.nrp_C)+1))/2.5;
                            
                            %Then allow traveling wave to move linearly across cortex, only
                            %considering RF centers.
                            [r_outer_ctx r_inner_ctx] = get_ring_edges(r_outer_ctx_max, r_inner_ctx_min, time_frac, duty);
                            
                            %then convert back to visual angle. Duty cycle is preserved.%
                            r_outer_deg = (self.nrp_C * (exp((2.5*r_outer_ctx))-1));
                            r_inner_deg = (self.nrp_C * (exp((2.5*r_inner_ctx))-1));
                            
                        otherwise
                            error('Not a valid type of scaling')
                    end
                    
                    % now, regadless of scaling, convert visual angle to pixels
                    r_outer_pix = r_outer_deg*ppd;
                    r_inner_pix = r_inner_deg*ppd;
                    
                case {'bar'}
                    if bar.scaling ~= 1
                        error('must use linear (1) scaling with bar stimulus')
                    end
                    % i'm using ring function for now, even though variable names are setup for rings and wedges
                    [b_outer_deg b_inner_deg] = get_ring_edges(bar.outer_deg_max, bar.inner_deg_min, time_frac, duty);

                    % now, regadless of scaling, convert visual angle to pixels
                    b_outer_pix = b_outer_deg*ppd;
                    b_inner_pix = b_inner_deg*ppd;

                otherwise
                    error('invalid direction supplied')
            end
            

            
            %% Check for flicker of stimulus
            if GetSecs > flicker_time
                flicker_time = flicker_time + flick_dur;
                if flicker_type == 2
                    flicker_type = 1;
                else
                    flicker_type = 2;
                end
            end
            
            
            %% update target-related variables
            % ...for both fixation and peripheral tasks
            if ~targ_on && GetSecs > timing.next_fix  && targ_allow  % if not currently "dimmed" and time for next fixation dimming (and we haven't disallowed target appearance)...
                % dim fixation cross
                switch attend_task
                    case 1 % FIXATION TASK
                        % ...update fixation spot color
                        fix.current_color = fix.dim_color;
                
                    case 2 % PERIPHERAL TASK
                        % ...what to update depends on background stimulus
                        switch stimulus
                            case {'checker','scenes'}
                                % for checkerboard stimulus, we'll overlay a target (solid color defined by dim_value) in the periphery,
                                % the shape and position (random) of which is dependent on the mask type
                                switch direction{currun}
                                    case {'cw' 'ccw'}
                                        % WEDGE
                                        % setup eccen of target ring
                                        if (wedge.cut_in - wedge.cut_out) < attend_checker_ring
                                            dim_outer = wedge.cut_in;
                                        else
                                            dim_outer = (wedge.cut_in-attend_checker_ring-wedge.cut_out) * rand + (attend_checker_ring+wedge.cut_out); % provides random target eccentricity for wedge mask
                                        end
                                        wedge_dim_rect = [xc-dim_outer, yc-dim_outer, xc+dim_outer, yc+dim_outer]; % for PTB Screen Drawing functions
                                        
                                    case {'out' 'in'}
                                        % RING
                                        % reset targ_base_angle so target is shown at a random angle for next target presentation
                                        targ_angle = 360*rand;
                                        
                                    case {'bar'}
                                        % BAR
                                        % for bar stimulus, choose new random location for peripheral target
                                        bar_dim_rho = 2*(rand-0.5) * bar_dim_maxrho; % random displacement along bar axis
                                end
                                
                            case 'dots'
                                % for dot motion, choose new coherent motion direction (at least some amount away from current direction
                                % how direction changes depends on 'direction'
                                switch direction{currun}
                                    case {'cw' 'ccw' 'out' 'in'}
                                        % WEDGE or RING
                                        cohdir = cohdir + (sign(rand-.5) * pi/180 * (attend_dots_mdir(1)+(attend_dots_mdir(2)-attend_dots_mdir(1))*rand)); % +/- random number in range defined by attend_dots_mdir (+ 50% sign flip)
                                    case {'bar'}
                                        % BAR
                                        % direction change target - direction always moves along bars main axis, and thus changes are always 180 deg
                                        cohdir = cohdir + pi; % always 180 deg for bar mask
                                        
                                        % speed change target
                                        % % dots.speed_pps = (dots.speed + sign(rand-.5)*attend_dots_speed) * ppd; % target dot speed (pix/sec)
                                        
                                        % color change target
                                        % % dots.color(:,coh) = repmat(dim_value,sum(coh),1)';
                                        
                                    otherwise
                                        error('cohdir change undefined for direction == %s',direction(currun))
                                end
                                coh = rand(dots.n,1) < dots.fcoh;	% choose a new set of coherently moving dots
                                mdir(coh) = cohdir; % update motion directions for newly coherently moving dots (some dots will continue to move in old direction, but should be swamped by new direction)
                        end
                end

                targ_on                = 1;
                targ_start             = GetSecs; % we'll be estimating this ~1 frame early since we haven't Flipped the screen yet, but not really a big deal
                this_behav.total_targs = this_behav.total_targs+1;
                timing.start_resp_time = targ_start;
                timing.check_target    = 1;
            
            elseif targ_on && GetSecs > targ_start+dim_length % if currently "dimmed" and duration of target presentation has passed...
                switch attend_task
                    case 1 % FIXATION TASK
                        % ...update fixation spot color
                        fix.current_color = fix.color;
                
                    case 2 % PERIPHERAL TASK
                        % ...what to update depends on background stimulus
                        switch stimulus
                            case {'checker','scenes'}
                                % nothing to do here...target (dim in stimulus) simply will not be drawn below
                                
                            case 'dots'
                                % direction change target - nothing to do, direction changes are sustained until next change
                                
                                % speed change target - reset dot speed
                                % % dots.speed_pps = dots_speed_orig * ppd; % normal dot speed (pix/sec)
                                
                                % color change target - reset dot color
                                % % dots.color = dots.orig_color;
                        end
                end

                targ_on = 0;
                timing.next_fix = GetSecs + min_targ + (max_targ-min_targ).*rand;
            end
            
            
            %% update stimulus based on the current time
            % Draw Stimulus
            switch stimulus
                case 'white' % solid white background
                    Screen('FillRect', w, 255, []); 
                    
                case 'checker' % checker board stimulus
                    if checker.checker_rot
                        checker_angle = (pi+ (2*pi*mod(GetSecs-start_time, checker.checker_rot)/checker.checker_rot ))*(180/pi);
                    end
                    Screen('DrawTexture',w,current_stim(flicker_type),[],[],checker_angle);
                    
                case 'scenes' % scene stimuli
                    error('scene stimuli haven''t been fully ported to the new code base yet...')
                    
                    %                     Screen('DrawTexture',w,current_stim(count));
                    %                     if flicker_type
                    %                         Screen('DrawTexture',w,checker_tex(1),[],[],[],[],flicker_type);
                    %                     end
                    
                case 'dots' % random dot motion
                    % update the dot positions based on time since last update
                    dot_dt = cur_time - last_dtime; % time (sec) since last update of dot position
                    dxdy = dots.speed_pps * dot_dt * [cos(mdir), sin(mdir)]; % change in x and y (in pixels) in pix since last update
                    xy = xy + dxdy; % move dots
                    last_dtime = cur_time;
                    
                    % locate dots that have moved beyond the border of the screen and update their position
                    x_out = xy(:,1) > xc | xy(:,1) < -xc; % check for dots beyond screen in x-dimension
                    y_out = xy(:,2) > yc | xy(:,2) < -yc; % check for dots beyond screen in y-dimension

                    % for dots that move beyond borders, just flip x (or y) position.  this is a simple way
                    % toi make sure that the density of dots in different parts of the screen is not influenced
                    % by the coherent motion direction
                    Lx = find(x_out); % locus of all dots that have gone beyond x border
                    nLx = length(Lx);
                    if nLx
                        xy(Lx,:) = repmat([-1 1],nLx,1) .* xy(Lx,:); % flip x coordinate
                    end
                    Ly = find(y_out); % locus of all dots that have gone beyond y border
                    nLy = length(Ly);
                    if nLy
                        % choose new dot positions for killed dots
                        xy(Ly,:) = repmat([1 -1],nLy,1) .* xy(Ly,:); % flip y coordinate
                    end
                   
                    % kill a small proportion of dots each "frame", to avoid be able to track a single dot
                    Lk = find(rand(dots.n,1) < dots.fkill); % locus of all dots that have gone beyond borders or are killed (including a random selection that will always die each frame)
                    nLk = length(Lk);
                    if nLk
                        % choose new dot positions for killed dots
                        xy(Lk,:) = [2*xc*rand(nLk,1)-xc 2*yc*rand(nLk,1)-yc]; % new random positions, bounded by screen (pixels)

                        mdir(Lk) = 2*pi*rand(nLk,1);	% random motion direction for each dot that was just killed
                        mdir(coh) = cohdir; % maintain coherence in motion (in case we killed dots that were part of the coherent motion signal)
                    end
 
                    Screen('DrawDots', w, xy', dots.size, dots.color, [xc yc], 2);
                    
                otherwise
                    error('invalid stimulus type provided')
            end
            
            
            %% draw the mask
            % IE, the solid overlay that defines the stimulus shape (e.g., wedge, ring or bar)
            switch direction{currun}
                case {'cw' 'ccw'}
                    % WEDGE SHAPE
                    if targ_on && attend_task == 2 && ismember(stimulus,{'checker','scenes'})
                        Screen('FrameArc',w, dim_value, wedge_dim_rect, 0, 360, attend_checker_ring, attend_checker_ring ); % peripheral ring target
                    end
                    Screen('FillArc', w, bg_color, cardinal_rect, stim_angle+(0.5*wedge_size), 360-wedge_size); % pac-man mask to define wedge
                    Screen('FrameArc', w, bg_color, corner_rect,0,360,corner_radius-(wedge.cut_in),corner_radius-(wedge.cut_in)); % mask everything beyond wedge.cut_in - defines max eccentricity shown
                                        
                    Screen('FillArc', w, bg_color, [xc-(wedge.cut_out), yc-(wedge.cut_out), xc+(wedge.cut_out), yc+(wedge.cut_out)], 0, 360); % central circular mask defining minimum eccentricity shown
            
                case {'out' 'in'}
                    % RING SHAPE
                    if targ_on && attend_task == 2 && ismember(stimulus,{'checker','scenes'})
                        Screen('FillArc', w, dim_value, cardinal_rect, targ_angle+(.5*attend_checker_wedge), attend_checker_wedge); % peripheral wedge target
                    end
                    Screen('FrameArc', w, bg_color, corner_rect,0,360,corner_radius-r_outer_pix,corner_radius-r_outer_pix); % mask everything beyond r_outer_pix - defines rings outer edge
                    Screen('FillOval', w, bg_color, [xc-r_inner_pix, yc-r_inner_pix, xc+r_inner_pix,yc+r_inner_pix]); % central circular mask defining ring's inner edge
                    
                case {'bar'}
                    % MOVING BAR STIMULUS
                    % N.B. target events are changes in motion direction and are taken care of above when updating dot position...
                    
                    % angle of current bar's starting point vector
                    bar_theta = -1 * (-this_bar_angle_deg-90) * (pi/180); % we want 0 deg up (top-to-bottom direction), positive cw, Matlab is 0 right, positive ccw.  need to transform for matlab's pol2cart

                    % debugging
                    if targ_on && attend_task == 2 && ismember(stimulus,{'checker','scenes'})
                        % draw "dimmed" (gray) rectangle orthogonal to bar as target

                        % dim angle is always offset of bar angle by 90 deg (random direction given sign of bar_dim_rho)
                        bar_dim_theta = bar_theta + pi/2; 
                        [dim_x dim_y] = pol2cart(bar_dim_theta, bar_dim_rho);
                        this_dim_rect = OffsetRect(bar_dim_rect,dim_x,dim_y);

                        Screen('DrawTexture', w, bar_dim_texid, [], this_dim_rect, this_bar_angle_deg, 0);
                        
                    end

                    if ~isnan(bar.cut_in)
                        Screen('FrameArc', w, bg_color, corner_rect,0,360,corner_radius-(bar.cut_in),corner_radius-(bar.cut_in)); % mask everything beyond dots.cut_in - defines max eccentricity shown
                    end

                    if isnan(this_bar_angle_deg)
                        % mask entire stimulus (fixation or null cycle)
                        Screen('FillRect',w, bg_color);
                    else
                        % partial stimulus mask that creates a moving bar
                        bar_mdir = 1; % 1 for top-to-bottom (for 0 angle), -1 for bottom-to-top (for 0 angle)
                                                
                        % draw "upper" mask
                        upper_ecc_pix = -corner_radius-b_outer_pix;
                        [upper_x upper_y] = pol2cart(bar_theta,upper_ecc_pix);
                        upper_rect = OffsetRect(bar_mask_rect,upper_x,upper_y);
                        Screen('DrawTexture', w, bar_mask_texid, [], upper_rect, this_bar_angle_deg, 0);
                        
                        % draw 'lower" mask
                        lower_ecc_pix = corner_radius-b_inner_pix;
                        [lower_x lower_y] = pol2cart(bar_theta,lower_ecc_pix);
                        lower_rect = OffsetRect(bar_mask_rect,lower_x,lower_y);
                        Screen('DrawTexture', w, bar_mask_texid, [], lower_rect, this_bar_angle_deg, 0);
                    end
                    
                    Screen('FillArc', w, bg_color, [xc-(bar.cut_out), yc-(bar.cut_out), xc+(bar.cut_out), yc+(bar.cut_out)], 0, 360); % central circular mask defining minimum eccentricity shown

                otherwise
                    error('invalid direction provided')
            end
            
            % account for "blank" periods (arbitary times of full screen mask)
            if isblank
                % mask entire screen
                Screen('FillRect',w, bg_color);
            end
            
            
            % add fixation spot to buffer and finalize buffer
            if ~take_screenshots
                add_fixspot(w,fix); % fixation spot
            end
            Screen('DrawingFinished', w);


            % Flip for the next frame
            if debugging
                loop_count = loop_count + 1;
                if loop_count <= loop_n
                    loop_dur(loop_count,1) = toc;
                else
                    a = 0; % for a break point
                end
            end
            
            Screen('Flip', w);
            
            % take screenshot here
            if take_screenshots
                this_screenshot = Screen('GetImage', w , [], [], 1, 1); % 1-channel, whole-window screen image of visible (front) buffer with floating-point precission (0-1)
                this_screenshot_filename = fullfile('screenshots',sprintf('screenshot_run%02d_n%03d_(%02dsec)',currun,screenshot_idx,cur_time)); % no extension
                switch screenshot_format
                    case {'m' 'matlab'}
                        % save as a matrix (probably easier since this is what we need to load to the pRF model, but not viewable in OSX easily)
                        save(this_screenshot_filename,'this_screenshot');
                    otherwise
                        % save as an image
                        imwrite(this_screenshot,[this_screenshot_filename '.' screenshot_format],screenshot_format);
                end
                
            end
            
            if debugging
                tic
            end

            % Check Button Responses
            [timing,key,this_behav]= CheckButtonResponse(timing,key,this_behav);
        end
        
        
        % Put fix on screen for end fixation period
        Screen('FillRect',w, bg_color); % fill background
        add_fixspot(w,fix); % fixation spot
        Screen('Flip', w);
        
        % Wait for end blank time
        start_end_blank = GetSecs;
        while GetSecs - start_end_blank < end_blank_time
            WaitSecs(0.001); % avoid CPU hogging
        end
        
        
        % store some run-specific information in the behav structure
        behav.runtime(currun)  = GetSecs - start_init_blank; % calculate runtime !!! including init_blank_time !!!
        this_behav.accuracy    = this_behav.hits/this_behav.total_targs;
        behav.accuracy(currun) = this_behav.accuracy;
        behav.hits(currun)         = this_behav.hits;
        behav.false_alarms(currun) = this_behav.false_alarms;
        behav.total_targs(currun)  = this_behav.total_targs;

        
        % Report behav.accuracy after each run
        Screen('FillRect',w, bg_color); % fill background
        txt1 = ['Your accuracy is: ' num2str(this_behav.accuracy)];
        txt2 = ['You had ' num2str(this_behav.false_alarms) ' false alarms'];
        txtloc = [xc - length(txt) * 7 / 2, yc];
        [newX newY] = Screen('DrawText',w,txt1,txtloc(1),txtloc(2)-15,white_index);
        [newX newY] = Screen('DrawText',w,txt2,txtloc(1),txtloc(2)+15,white_index);
        Screen('Flip',w,[],1);
        if ~take_screenshots
            WaitSecs(5);
        end

        if debugging
            fprintf('\nmean loop_dur = %f\n',nanmean(loop_dur))
        end
        fprintf('\nRun Duration: actual = %.02f   expected = %.02f\n', behav.runtime(currun), ncycles * cycle_duration + init_blank_time + end_blank_time)

        % intermitent save (in case we quit/crash half way through a run, we'll still have data for already completed runs)
        if savefile
            save(fullfile('data',filename),'options','behav'); % save options and behav structures in data subdirectory
        end
    end
    
    %% final save and cleanup
    if savefile
        save(fullfile('data',filename),'options','behav'); % save options and behav structure in data subdirectory
    end
    
    Screen('CloseAll'); % close any open screens/windows
    ShowCursor;         % restore cursor visibility
    ListenChar(0);      % keystrokes make it to command line/editor (Ctrl-c)
    Priority(0);        % restore normal processing priority
    
    
catch
    % this "catch" section executes in case of an error in the "try" section
    % above.  Importantly, it closes the onscreen window if its open.
    
    % it is necessary to save the error message for this try...catch in
    % case some of the clean-up code includes a try...catch that might
    % overwrite the error message (i.e., ListenChar(0); seems to do this)
    thiserror = lasterror();
    
    % save workspace!  otherwise we'll potentially loose all access to the data
    save('./crash_dump.mat');
    fprintf('\n#----------------------------------#\nsaving workspace in ./crash_dump.mat\n#----------------------------------#\n')

    % Clean up in case of an error in main code
    Screen('CloseAll'); % close any open screens/windows
    ShowCursor;         % restore cursor visibility
    ListenChar(0);      % keystrokes make it to command line/editor (Ctrl-c)
    Priority(0);        % restore normal processing priority
    
    % rethrow error, but print STACK first!
    %    "I'm the boss, need the info..." -Dr Evil
    display(sprintf('\n'));
    for i = 1:length(thiserror.stack)
        display(thiserror.stack(i));
    end
    rethrow(thiserror); % display error message that caused crash
    
    
end %try..catch..
end


function [r_outer r_inner] = get_ring_edges(r_outer_max, r_inner_min, time_frac, duty) %This generic function can be used to generate linearly scaled rings on screen or on cortex.
r_width = duty*(r_outer_max-r_inner_min)/(1-duty); %fixed width of ring; (can obtain by solving for r_width in duty = r_width/(r_outer_max+r_width-r_inner_min)
r_outer_max_NOBLOCK = r_outer_max + r_width; %how far outer ring would go if there was no blocking ("blocking" is stopping the movement of the outer ring near the end of the cycle)

r_outer = r_inner_min + time_frac*((r_outer_max_NOBLOCK)-r_inner_min);% provisionally placing outer ring somewhere between r_inner_min and the maximum possible value if no blocking was done

r_inner = r_outer - r_width; %provisionally making inner ring a fixed distance inside outer ring;

r_outer = min(r_outer, r_outer_max); %... but blocking outer ring from going past its maximum allowed value.
r_inner = max(r_inner, r_inner_min); %...and not letting inner ring go below an assigned minimum (usually zero).
end


function [] = add_fixspot(w,fix)
% add fixation spot to screen buffer using info in fix structure

%Screen('FillRect', w, fix.current_color, fix.rect); % outer box, or solid square if size_inner is zero
Screen('FillOval', w, fix.current_color, fix.rect); % outer box, or solid square if size_inner is zero
if fix.size_inner > 0
    %Screen('FillRect', w, fix.bg_color, fix.rect_inner); % inner dot
    Screen('FillOval', w, fix.bg_color, fix.rect_inner); % inner dot
end

end


function [timing key behav] = CheckButtonResponse(timing, key, behav)
% check for canceling, so easy to exit out for debugging
if timing.check_target % get response for last targ letter
    
    if GetSecs > timing.start_resp_time + timing.resp_interval
        timing.check_target=0;
    end
    
    [keyIsDown, secs, keycode] = KbCheck(key.dev_id); %check response
    
    if keycode(key.quit_key)
        key.quit=1;
    elseif find(keycode(key.resp_key))%if hit response key
        behav.hits = behav.hits + 1;
        timing.check_target=0;
        timing.check_prior=1;
        
    end
else % check for false alarms
    [keyIsDown, secs, keycode] = KbCheck(key.dev_id); %check response
    
    if keycode(key.quit_key)
        key.quit=1;
    elseif find(keycode(key.resp_key))%if hit response key
        if ~timing.check_prior
            behav.false_alarms=behav.false_alarms+1;
            timing.check_prior=1; %cause got a response
        end
    else
        %response bottom not down, will allow responses to be recorded agaiin
        timing.check_prior=0;
    end
    %__________________end response check
end
end


function [merged unused] = propval(propvals, defaults, varargin)

% Create a structure combining property-value pairs with default values.
%
% [MERGED UNUSED] = PROPVAL(PROPVALS, DEFAULTS, ...)
%
% Given a cell array or structure of property-value pairs
% (i.e. from VARARGIN or a structure of parameters), PROPVAL will
% merge the user specified values with those specified in the
% DEFAULTS structure and return the result in the structure
% MERGED.  Any user specified values that were not listed in
% DEFAULTS are output as property-value arguments in the cell array
% UNUSED.  STRICT is disabled in this mode.
%
% ALTERNATIVE USAGE:
%
% [ ARGS ] = PROPVAL(PROPVALS, DEFAULTS, ...)
%
% In this case, propval will assume that no user specified
% properties are meant to be "picked up" and STRICT mode will be enforced.
%
% ARGUMENTS:
%
% PROPVALS - Either a cell array of property-value pairs
%   (i.e. {'Property', Value, ...}) or a structure of equivalent form
%   (i.e. struct.Property = Value), to be merged with the values in
%   DEFAULTS.
%
% DEFAULTS - A structure where field names correspond to the
%   default value for any properties in PROPVALS.
%
% OPTIONAL ARGUMENTS:
%
% STRICT (default = true) - Use strict guidelines when processing
%   the property value pairs.  This will warn the user if an empty
%   DEFAULTS structure is passed in or if there are properties in
%   PROPVALS for which no default was provided.
%
% EXAMPLES:
%
% Simple function with two optional numerical parameters:
%
% function [result] = myfunc(data, varargin)
%
%   defaults.X = 5;
%   defaults.Y = 10;
%
%   args = propvals(varargin, defaults)
%
%   data = data * Y / X;
%
% >> myfunc(data)
%    This will run myfunc with X=5, Y=10 on the variable 'data'.
%
% >> myfunc(data, 'X', 0)
%    This will run myfunc with X=0, Y=10 (thus giving a
%    divide-by-zero error)
%
% >> myfunc(data, 'foo', 'bar') will run myfunc with X=5, Y=10, and
%    PROPVAL will give a warning that 'foo' has no default value,
%    since STRICT is true by default.
%

% License:
%=====================================================================
%
% This is part of the Princeton MVPA toolbox, released under
% the GPL. See http://www.csbmb.princeton.edu/mvpa for more
% information.
%
% The Princeton MVPA toolbox is available free and
% unsupported to those who might find it useful. We do not
% take any responsibility whatsoever for any problems that
% you have related to the use of the MVPA toolbox.
%
% ======================================================================

% Backwards compatibility
pvdef.ignore_missing_default = false;
pvdef.ignore_empty_defaults = false;

% check for the number of outputs
if nargout == 2
    pvdef.strict = false;
else
    pvdef.strict = true;
end

pvargs = pvdef;

% Recursively process the propval optional arguments (possible
% because we only recurse if optional parameters are given)
if ~isempty(varargin)
    pvargs = propval(varargin, pvdef);
end

% NOTE: Backwards compatibility with previous version of propval
if pvargs.ignore_missing_default | pvargs.ignore_empty_defaults
    pvargs.strict = false;
end

% check for a single cell argument; assume propvals is that argument
if iscell(propvals) && numel(propvals) == 1
    propvals = propvals{1};
end

% check for valid inputs
if ~iscell(propvals) & ~isstruct(propvals)
    error('Property-value pairs must be a cell array or a structure.');
end

if ~isstruct(defaults) & ~isempty(defaults)
    error('Defaults struct must be a structure.');
end

% check for empty defaults structure
if isempty(defaults)
    if pvargs.strict & ~pvargs.ignore_missing_default
        error('Empty defaults structure passed to propval.');
    end
    defaults = struct();
end

defaultnames = fieldnames(defaults);
defaultvalues = struct2cell(defaults);

% prepare the defaults structure, but also prepare casechecking
% structure with all case stripped
defaults = struct();
casecheck = struct();

for i = 1:numel(defaultnames)
    defaults.(defaultnames{i}) = defaultvalues{i};
    casecheck.(lower(defaultnames{i})) = defaultvalues{i};
end

% merged starts with the default values
merged = defaults;
unused = {};
used = struct();

properties = [];
values = [];

% To extract property value pairs, we use different methods
% depending on how they were passed in
if isstruct(propvals)
    properties = fieldnames(propvals);
    values = struct2cell(propvals);
else
    properties = { propvals{1:2:end} };
    values = { propvals{2:2:end} };
end

if numel(properties) ~= numel(values)
    error(sprintf('Found %g properties but only %g values.', numel(properties), ...
        numel(values)));
end

% merge new properties with defaults
for i = 1:numel(properties)
    
    if ~ischar(properties{i})
        error(sprintf('Property %g is not a string.', i));
    end
    
    % convert property names to lower case
    properties{i} = properties{i};
    
    % check for multiple usage
    if isfield(used, properties{i})
        error(sprintf('Property %s is defined more than once.\n', ...
            properties{i}));ring
    end
    
    % Check for case errors
    if isfield(casecheck, lower(properties{i})) & ...
            ~isfield(merged, properties{i})
        error(['Property ''%s'' is equal to a default property except ' ...
            'for case.'], properties{i});
    end
    
    % Merge with defaults
    if isfield(merged, properties{i})
        merged.(properties{i}) = values{i};
    else
        % add to unused property value pairs
        unused{end+1} = properties{i};
        unused{end+1} = values{i};
        
        % add to defaults, just in case, if the user isn't picking up "unused"
        if (nargout == 1 & ~pvargs.strict)
            merged.(properties{i}) = values{i};
        end
        
        if pvargs.strict
            error('Property ''%s'' has no default value.', properties{i});
        end
        
    end
    
    % mark as used
    used.(properties{i}) = true;
end
end

