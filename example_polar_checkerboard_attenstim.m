%Stim Parameters for Polar Angle Mapping w/ attention dimming task @ stim
clear options

% Datafile --------------------------------
options.subj               =   'test';

% Screen and Display --------------------------------
% change to match your scanner situation.
options.screen_w = 50;                          % screen width in cm. scanner 39, most lcds 50 
options.screen_d = 60;                          % screen viewing distance (cm)
options.bg_color = 0*[1 1 1];         % background color on 0-255 [R G B] scale


% Response --------------------------------
options.key.quit_key           =   KbName('Escape');     % Q for quit
options.key.resp_key           =   KbName('LeftArrow');  % response button, 44 for Keyboard, 33 for button box


% Timing ----------------------------------------------------
options.ncycles            =   8;          % number of cycles
options.cycle_duration     =   40;         % duration (sec) of a single cycle (eg, rotation period of wedge or ring). *** should be an increment of the TR ***
options.init_blank_time    =   0;          % initial blank time (sec)
options.end_blank_time     =   0;          % blank time at end (sec)


% Fixation Point ----------------------------------------------------
options.fix.color          =   [255 0 0];     % color of fixation spot


% Stimulus ----------------------------------------------------
% stimuli are displayed full-screen.  'mask' defines how much and which part of the stimulus is visible at any point in time.
options.stimulus = 'checker'; % type of visual stimulus.  'checkerboard' or 'dots'

% moving dots
options.dots.n 	   = 13000;	        % number of dots
options.dots.speed = 7;	            % normal dot speed (deg/sec)
options.dots.size  = 6;             % dot width (pixels)
options.dots.color = [255 255 255]'; % repmat([0 0 0; 255 255 255],options.dots.n/2,1)';%[255 255 255]; % vector [R G B] color of each dot.  Can define color separately for each dot in an 3xNDOTS                matrix
options.dots.fcoh  = 0.40;	        % fraction of coherent dots moving in same direction.  these dots change direction for peripheral target when using dots stimuli.
options.dots.fkill = 0.1; 	        % fraction of dots to kill each frame (to avoid subject being able to track a single dot for peripheral task)


% Attention Task ----------------------------------------------------
options.attend_task         =   2;                 % 1 for fixation dimming task, 2 for peripheral (ring/wedge/dots)
options.dim_value           =   [137 137 137 210]; % dim color (0-255 [R G B A]) for checkerboard attention task
options.dim_length          =   0.3;               % duration (sec) of fixation and ring/wedge dimming events
options.min_targ            =   3;                 % minimum time (sec) between target events
options.max_targ            =   5;                 % maximum time (sec) between target events
options.attend_checker_ring  =   1;          % atten ring duty cycle (width) for wedge mask
options.attend_checker_wedge =   15;         % degress of atten wedge size for ring mask
options.attend_checker_bar   =   1;          % width (deg) of atten bar size for bar mask

% Mask ----------------------------------------------------
% General - shared across all masks
% N.B. the mask type is inherently defined by the direction
options.duty                = 0.125;   % duty cycle (0.125 = 12.5%): fraction of cycle time that stimulus is visible at any one point.  For wedge, angular size is 360 * duty.
options.direction           = {'cw', 'cw'};        % cell array of strings, one for each run.  options are wedge:'cw','ccw'     ring:'in','out'     bar:'bar'
options.transition          = 'smooth';  % 'smooth' for continuous updating of position and smoothly moving mask, 'discrete' for for static mask positions changes (see options.discrete.order)

% additional options for discrete transitions
options.discrete.order       = 'straight'; % defines the order of cycling through all possible cycle-step pairs.  'straight' (default) for straight progression, 'random' for random order, or vector containing values 1:(ncycles*steps_per_cycle) defining index of cycle-step pairs to move through
options.discrete.step_size   = 2; % (sec) if discrete.step_size is true, how long does the mask stay in one position?  in other words, at what time is the mask updated to step to the next position?  if 'calculate' the discrete.step_size will be calculated such that each point on the screen is part of one and only one step
options.discrete.step_offset = 'half_step_size'; % time offset (sec) to shift each discrete step by.  If 0, the first step will not show a simulus (or rather a sliver of one).  By default, it is 'half_step_size', which will be calculated as discrete.step_size/2.

% Rotating Wedge - standard polar angle mapping - ('cw' or 'ccw')
options.wedge.cut_out     =   0.25;        % cut out n deg (radius) from center. set to zero for no cut_out.
options.wedge.cut_in      =   15;         % cut in n deg (radius) from outer max; defines extent (max eccen) of wedge

% Ring Properties - standard eccentricity mapping - ('in' or 'out')
options.ring.outer_deg_max =   15;         % outer maximum stimulation point for ring
options.ring.inner_deg_min =   0;          % inner minimum stimulation point for ring (must be >=0)
options.ring.scaling       =   1;          % 1 for linear, 2 for pure logarithmic, 3 log-based cortical magnification ala Boynton & Duncan, 2002

% Bar Properties - PRF mapping - ('bar', but note that bar.angles is needed to define specific bar directions)
angs = 0:(360/options.ncycles):(360-360/options.ncycles);
angs_shuff = angs([5 2 3 8 4 7 6 1]); % pre-determined random order for 8 ncycles
t1i1_idx = [1 2 3 4 5 6 7 8; 8 1 5 2 4 7 3 6; 6 5 3 1 7 2 8 4; 4 3 2 6 1 8 5 7; 7 6 4 8 2 5 1 3; 3 8 7 5 4 1 6 2; 2 7 1 4 6 8 3 5; 5 8 6 3 7 4 2 1]; % from Theobald website
options.bar.angles        =   angs_shuff(t1i1_idx);  % bars move perpendicular to the bar.angles vectors.  0 is top-to-bottom, 90 is right-to_left, 45 is upperRight-to-lowerLeft, etc. use NaN for fiation-only (no stimulus, null) cycles.  Must be the same length as ncycles
options.bar.outer_deg_max =   15;         % outer maximum stimulation point for bar (N.B. we are hijacking the ring code, so you can think of bar max as being tanjential to ring max)
options.bar.inner_deg_min =   -options.bar.outer_deg_max; % inner minimum stimulation point for bar (N.B. we are hijacking the ring code, so you can think of bar min as being tanjential to ring min)
options.bar.cut_out       =   0.3;        % cut out n deg (radius) from center. set to zero for no cut_out. might be useful to keep stimulus off of fixation spot
options.bar.cut_in        =   options.ring.outer_deg_max;        % cut in n deg (radius) from outer max; equals max eccen of wedge.  set to NaN for no cut_in.


% Blanks ----------------------------------------------------
% Use these parameters to create arbitrarily timed blank periods.
options.blanks = []; % Nx3 element matrix (e.g., [3 0.5 1; 4 0.33 0.66] where each row-triplet defines a blank period.  The 1st column is the cycle during which the blank occurs and the 2nd and 3rd columns defined when the blank starts and stops, respectively, in time_fraction units.  A full cycle goes from 0-1. In the example given, there would be no stimulus during the 2nd half of the 3rd cycle and the middle 3rd of the 4th cycle.


% Extras ----------------------------------------------------
options.debugging         = 0; % if true, will not HideCursor or ListenChar(2) and will keep track of the duration of each frame


TravelingWave(options);
ShowCursor;