function Born2Hear_WP1ctr(ID,varargin)
%% runs Born2Hear experiment
%
% variables
% spectral profile: native(1) or inverted (-1); col 1
% Direction (D): looming (-1) or receding (1); col 2
%
% speaker position: LAS 23, 9, 74, 54
% lateralization of stimulus: left (1) or right (-1); col 4
% trigger value onset passive; col 5
% trigger value change passive; col 6
% trigger value onset active; col 7
% trigger value change active; col 8
%frequency of stimulus (1:12); col 9
%
% E (externalized response): closer (-1) or farther (1)
% hit: correct response (1) or wrong response (0)

%% start deleting everything
saveFileNamePrefix = 'Exp1_ctr';

%% Experimental variables
definput = arg_Born2Hear;
[flags,kv]  = ltfatarghelper({},definput,varargin);

%% Listener ID
% if isempty(ID) % not(exist('ID','var'))
%   subj.ID = upper(input('Enter subject ID: ','s'));
% else
%   subj.ID = ID;
% end

subj.ID = ID;

%% Save path

if flags.do_laptop
    savename = fullfile('data',[saveFileNamePrefix '_' subj.ID]);

    if not(exist('./data','dir'))
      mkdir('data')
    end
else
    addpath('\\W07kfs4\eap\Organization\Experiments\Subject Data');
    s = Subjects_Get;
    match = find((reshape(strcmp({s.ID}, ID), size(s)))==1);
    name = s(match).name;
    savepath = fullfile('\\W07kfs4\eap\Resources\Experimental_Data\Main Experiments\NH',name,'Born2Hear\WP2');
    
    if not(exist(savepath))
      mkdir(savepath)
    end
    
    savename = fullfile(savepath,[saveFileNamePrefix '_' subj.ID]);
end
%% Internal seetings
KbName('UnifyKeyNames');

spaceKey = KbName('Space');

closerKey = KbName('rightArrow'); % for looming stimuli
fartherKey = KbName('leftArrow'); % for receding stimuli

if flags.do_eeg
    trigVals = struct(...
      'startBlock',193,...
      'endBlock',192,...
      'closerHit',202,...
      'fartherHit',198,...
      'closerMiss',200,...
      'fartherMiss',196,...
      'stimulusOffset',224);
end

if flags.do_eeg
    % sampling rate of the trigger channel
    fsd=1000;   
    % Encode as binaury
    stimVec=[ones(40,1); -ones(40,1)];
    % length signal
    siglen=kv.fs*kv.dur;
    % upsample to the audio sampling rate
    stimVec=resample(stimVec, kv.fs, fsd);
    stimVec=[stimVec;zeros(siglen-length(stimVec),1)];
    stimVec=[stimVec zeros(siglen,1)]; %StimTrak: send stimVec as third channel
end

%% Check availability of dependent functions
if not(exist('Born2Hear_stim','file'))
  addpath(fullfile('..','MATLAB_general'))
end
if not(exist('fftreal','file'))
  amtstart
end

%% set random seed

rs = RandStream('mt19937ar', 'Seed', sum(100*clock)); % initiate random number generator based on some value derived from current time
RandStream.setGlobalStream(rs);

%% Initialize virtual serial port for trigger

if flags.do_eeg
    TB = IOPort('OpenSerialPort', 'COM3');
    % Read data from the TriggerBox
    Available = IOPort('BytesAvailable', TB);
    if(Available > 0)
        disp(IOPort('Read', TB, 0, Available));
    end
    % Set the port to zero state 0
    IOPort('Write', TB, uint8(0), 0);
    pause(0.01);
end
%% Initialize PsychPortAudio

InitializePsychSound(1); %inidializes sound driver...the 1 pushes for low latency

if flags.do_laptop
    devices = PsychPortAudio('GetDevices', [], []);
    outputDevice = devices(find([devices.NrOutputChannels] == 2, 1, 'first')).DeviceIndex;
else
    outputDevice = 13;
end

pahandle = PsychPortAudio('Open', outputDevice, 1, 1, kv.fs, 2);

if flags.do_eeg
    pahandle = PsychPortAudio('Open', outputDevice, 1, 1, kv.fs, 4); % 4 channels (1&2 signal, 3&4 StimTrak)
else
    pahandle = PsychPortAudio('Open', outputDevice, 1, 1, kv.fs, 2);
end

%% Initialize the graphical interface for Psychtoolbox

% ignore screen warning!
Screen('Preference', 'SkipSyncTests', 1);

PsychDefaultSetup(1); % makes sure Screen is functional and unifies keyCodes across OS
HideCursor;

screens = Screen('Screens');

white = [255 255 255]; %WhiteIndex(screenNumber);
black = [0 0 0]; %BlackIndex(screenNumber);
blue = [0 0 255];
green = [0 255 0];
red = [255 0 0];

if flags.do_debugMode
    debugRect = [10 10 200 200];
    [win,winRect] = Screen('OpenWindow',kv.screenNumber,black,debugRect);
    ShowCursor;
else
    [win,winRect] = Screen('OpenWindow',kv.screenNumber, black);
end

Screen('TextSize',win, 20);
[screenXpix,screenYpix] = Screen('WindowSize', win);
[x_center,y_center] = RectCenter(winRect);

%% Listener instruction passive part
if flags.do_eeg
    instructionP=[...
       'Herzlich Willkommen zum Experiment!\n\n',...
       'Sie werden nun f??r ca. 15 min einen Film mit Untertitel ohne Tonspur sehen. Ihre Aufgabe ist es, sich NUR auf den Film zu konzentrieren, und die Ger??usche zu ignorieren. ',...
       'Am Ende werden Ihnen Fragen zum Film gestellt.\n\n',...
       'Bitte versuchen Sie, sich w??hrend des Films m??glichst wenig zu bewegen!\nNach 8 min pausiert der Film und Sie k??nnen eine Pause einlegen.\n\n',...
       'Sollten die Ger??usche unangenehm laut sein, bitte sofort der Versuchsleitung Bescheid geben.\n\n',...
       'Haben Sie noch Fragen?\n\n',...
       'Zum Starten die Leertaste dr??cken.'];
end

%% Listener instruction active part
instructionA = [...
  'In diesem Experiment h??ren Sie Paare aus zwei Ger??uschen. Konzentrieren Sie sich nur auf deren Unterschied bez??glich \n',... 
  'r??umlicher ENTFERNUNG (relativ zur Mitte Ihres Kopfes gesehen). \n',...
  'Versuchen Sie andere Unterschiede wie r??umliche H??he, Intensit??t oder Tonh??he zu ignorieren. \n',...
  '\n',...
  'Ihre Aufgabe w??hrend des Experiments ist es...\n',...
  '   den rechten Pfeil zu dr??cken, wenn das ZWEITE Ger??usch N??HER an ihrem Kopf erscheint als das erste \n',...
  '   den linken Pfeil zu dr??cken, wenn das ZWEITE Ger??usch ENTFERNTER von ihrem Kopf erscheint als das erste \n'];

instructionA = [instructionA,...
  '\n',...
  'Antworten Sie so schnell wie m??glich!\n\n',...
  'Bitte richten Sie Ihren Blick w??hrend der Ger??uschwiedergabe stets auf den wei??en Punkt in der Mitte des Bildschirms. \n'];
instructionA= [instructionA,...
   'Nach der H?lfte des Experiments haben Sie die M??glichkeit eine Pause einzulegen.\n\n'];

if flags.do_beh
    instructionA=[instructionA,...
    'Sollten die Ger??usche unangenehm laut sein, geben Sie bitte sofort der Versuchsleitung Bescheid! \n',...
    '\n'];
end
instructionA= [instructionA,...
    'Bevor das Experiment beginnt, h??ren Sie ein paar Tonbeispiele, um die Aufgabe zu ??ben. \n'];

instructionA=[instructionA,...
  'Haben Sie noch Fragen? \n',...
  'Zum Starten '];
if flags.do_familiarize
    instructionA=[instructionA,...
    'der ??bungsdurchg??nge '];
end
instructionA=[instructionA,...
   'bitte die Leertaste dr??cken.'];

DrawFormattedText(win,instructionA,.2*x_center,'center',white,120,0,0,1.5);
Screen('Flip',win);

%% load stimuli and positions

if flags.do_laptop
    load(fullfile('data',['stimuliC_lLR_' ID]));
else
    load(fullfile(savepath,['stimuliC_lLR_' ID]));
end

%% Create trial list
% t1 : 4x native (1) and 4x inverted (-1) 
% t2 : 4x looming (-1) and 4x receding (1)
% t3 : LAS pos -> 4 pos left (23, 9, 74, 54)
% condition -> reference to column in stim.sig
% looming/receding, native/inverted and LASpos are cross-referenced such
% that each stimulus is played once from every position 

% t4 : lateralization of each speaker position (left 1, right -1)
% t5 : trigger at onset active
% t6 : trigger at change active
% t7 : frequency of stim (12 different freqs) -> reference to 3rd dimension
% in stim.sig

t1=repelem([-1,1],4)'; 
t2=repelem([-1,1,-1,1],2)';
t3=repmat([23,9,74,54],1,2)'; % LAS pos
t4=repmat([1,-1],1,4)';

% trigger for active onset t5 and active change t6
% calculation of a different trigger depending on whether the signal is
% native/inverted ; looming/receding
% trigger for LEFT!
for n = 1:length(t1)
    if t1(n) == -1 && t2(n) == -1
        t5(n) = 142;
        t6(n) = 174;
    elseif t1(n) == -1 && t2(n) == 1
        t5(n)= 143;
        t6(n) = 175;
    elseif t1(n) == 1 && t2(n) == -1
        t5(n)= 141;
        t6(n) = 173;
    elseif t1(n) == 1 && t2(n) == 1
        t5(n)= 140;
        t6(n) = 172;
    end
end

% calculation of different trigger for different positions
% 9: Front-Up = +4
% 23: Front-Down = +8 
% 54: Back-Up = +12 
% 74: Front-Down = +16 
for n = 1:length(t3)
    if t3(n) == 9
        t5(n)=t5(n)+4;
        t6(n)=t6(n)+4;
    elseif t3(n) == 23
        t5(n)=t5(n)+8;
        t6(n)=t6(n)+8;
    elseif t3(n) == 23
        t5(n)=t5(n)+12;
        t6(n)=t6(n)+12;
    elseif t3(n) == 23
        t5(n)=t5(n)+16;
        t6(n)=t6(n)+16;
    end
end


% create trial table from vectors t1 to t5 (corresponding to 1 repetition!)
trialList = [t1,t2,t3,t4,t5',t6'];

stimTest = trialList;
% repeat matrix 50 times (such that the list contains 100 trials
% respectively for inverted & native conditions on the left and the right
trialList = repmat(trialList,50,1); 

% frequencies
t7=repelem([1:kv.Fr],ceil(length(trialList)/kv.Fr));
t7=t7(randperm(length(t7)))';
trialList(:,7)=t7(1:length(trialList));

stimTest(:,7)=t7(1:length(stimTest(:,1)));
stimTest = stimTest(randperm(size(stimTest,1)),:);
% randomize the trialList & then sort trials such that left/right trials
% are blocked (whether left or right comes first is also randomized) + such
% that inverted/native trials are blocked (inverted always precedes native to minimize bias)

randomized_dummy = trialList(randperm(size(trialList, 1)), :);


lr = randi([1,2]);
if lr == 1
    sorted_dummy = sortrows(randomized_dummy, 3, {'ascend'});
else
    sorted_dummy = sortrows(randomized_dummy, 3, {'descend'});
end

contrast_sorted = sortrows(randomized_dummy, 1);


% contrast_sorted(1:100,:) = sortrows(contrast_sorted(1:100,:),3);
% contrast_sorted(100:200,:) = sortrows(contrast_sorted(100:200,:),3,{'ascend'});
% contrast_sorted(200:300,:) = sortrows(contrast_sorted(200:300,:),3,{'ascend'});
% contrast_sorted(300:400,:) = sortrows(contrast_sorted(300:400,:),3,{'ascend'});


% the final trial list is a randomization of the trialList table
subj.trials = sorted_dummy;

% Set values
subj.D = subj.trials(:,2); % 1st column: looming (-1) or receding (1)
subj.pos = subj.trials(:,3); % speaker positions (37 or 82)

%% stimulus testing
% sequence of stimuli to test noises & familiarize subjects with task
if flags.do_familiarize
    
    pause(1)
    % wait for space key
    keyCode(spaceKey) = 0;
    while keyCode(spaceKey) == 0
        [secs, keyCode] = KbWait;
    end
    
    pause(1.5)  % add a pause to ensure the pause is active before the sound 

    % Fixation point
    Screen('DrawDots',win, [x_center,y_center], 14, white, [], 2);
    Screen('Flip',win);
    pause(1)
    
    for n = 1:length(stimTest(:,1))
        if stimTest(n,1) == -1
                if stimTest(n,2) == -1
                    c1 = 2;
                    c2 = 3;
                else
                    c1 = 3;
                    c2 = 2;
                end
            else
                if stimTest(n,1) == -1
                    c1 = 1;
                    c2 = 3;
                else 
                    c1 = 3;
                    c2 = 1;
                end
        end

        pp=stimTest(n,3); % position of loudspeaker (37 or 82)
        ff=stimTest(n,9); % frequenz of stimulus - one of 12 different freqs -> 3rd dimension in stim.sig

        % combine stimulus pairs with temporal jitter of crossfade
        dt = kv.jitter*(rand-0.5);
        subj.tempJ(n,1) = dt;
        % time for onset second stimulus
        onsetChange = kv.dur/2+dt-kv.xFadeDur/2;

        [sigpair,nM2] = Born2Hear_crossfade(stim.sig{c1,pp,ff},stim.sig{c2,pp,ff},...
        stim.fs,kv.dur,kv.dur/2+dt,kv.xFadeDur,'argimport',flags,kv);

        % playback
        if flags.do_eeg % with StimTrak
            PsychPortAudio('FillBuffer', pahandle, [sigpair stimVec]');
        else
            PsychPortAudio('FillBuffer', pahandle, sigpair');
        end
        
        tic;
        PsychPortAudio('Start', pahandle, 1, 0, 1);
        
        if flags.do_beh
         pause(onsetChange)
        end

        % Get response via keyboard 
        keyCodeVal = 0;

        while not(any(keyCodeVal==[closerKey,fartherKey]))
        [tmp,keyCode] = KbWait([],2);
        keyCodeVal = find(keyCode,1);
        end
        
        respPress=toc;
        
         Screen('FillRect',win,black);
         Screen('Flip',win);
         % for responses during stimuliation, wait until end of stimulation
         if respPress < (kv.dur-onsetChange)
             pause(kv.dur-respPress-onsetChange)
         end
         pause(0.3)
         Screen('DrawDots',win, [x_center,y_center], 14, white, [], 2);
         Screen('Flip',win);
         
    end
    
    instruction2 = [...
      'YAY - ?bungsdurchg?nge erfolgreich abgeschlossen! \n',...
      'Haben Sie noch Fragen?\n',...
      'Wenn nicht, dr?cken Sie die Leertaste um das Experiment zu starten.\n'];
    DrawFormattedText(win,instruction2,'center','center',white,120,0,0,1.5);
    Screen('Flip',win);
    
     % Experimenter monitoring info
    disp('Info given to listener:')
    disp(instruction2)
    
end

%% passive condition

if flags.do_eeg
    
    % initialize movie
    moviename = 'C:\Users\experimentator\Videos\movie_passive.mp4';
    v = VLC();
    
    % wait for space key
    keyCode(spaceKey) = 0;
    while keyCode(spaceKey) == 0
        [secs, keyCode] = KbWait;
    end
    
    sca;
    
    v.play(moviename);
    
    % trigger block start
    IOPort('Write', TB, uint8(trigVals.startBlock), 0);
    pause(0.01);
    IOPort('Write', TB, uint8(0), 0);
    pause(0.01);

    pause(1.5)  % add a pause to ensure the pause is active before the sound 
        
        
    % presentation of stimuli
    for n = 1:length(subj.trials(:,1))

    % if the trial is a looming trial -> then the contrast reference of the first
    % signal (c1) is 1 or 2 depending on whether it is a
    % native/inverted condition -> 1/2 references the row of the stim.sig
    % table, where stim.sig(1,:)=1 stim.sig(2,:)=-1 stim.sig(3,:)=0
    % vice versa with receding trials
    %
    % stim crossover is always c1 -> c2
    % 1 -> 0 is looming native
    % 0 -> 1 is receding native
    % -1 -> 0 is looming inverted
    % 0 -> -1 is receding inverted

        if subj.trials(n,1) == -1
            if subj.trials(n,2) == -1
                c1 = 2;
                c2 = 3;
            else
                c1 = 3;
                c2 = 2;
            end
        else
            if subj.trials(n,1) == -1
                c1 = 1;
                c2 = 3;
            else 
                c1 = 3;
                c2 = 1;
            end
        end

        pp=subj.trials(n,3); % position of loudspeaker (37 or 82)
        ff=subj.trials(n,9); % frequenz of stimulus - one of 12 different freqs -> 3rd dimension in stim.sig

        % combine stimulus pairs with temporal jitter of crossfade
        dt = kv.jitter*(rand-0.5);
        subj.tempJ(n,1) = dt;
        % time for onset second stimulus
        onsetChange = kv.dur/2+dt-kv.xFadeDur/2;

        [sigpair,nM2] = Born2Hear_crossfade(stim.sig{c1,pp,ff},stim.sig{c2,pp,ff},...
        stim.fs,kv.dur,kv.dur/2+dt,kv.xFadeDur,'argimport',flags,kv);

        % playback
        if flags.do_eeg % with StimTrak
            PsychPortAudio('FillBuffer', pahandle, [sigpair stimVec]');
        else
            PsychPortAudio('FillBuffer', pahandle, sigpair');
        end

        PsychPortAudio('Start', pahandle, 1, 0, 1);

        % trigger: timestamp for onset/change & exp. condition (1-32)
        if flags.do_eeg 
            IOPort('Write', TB, uint8(subj.trials(n,5)), 0);
            pause(0.01);
            IOPort('Write', TB, uint8(0), 0);
            pause(onsetChange-0.01); % wait until start of crossfade

            IOPort('Write', TB, uint8(subj.trials(n,6)), 0);
            pause(0.01);
            IOPort('Write', TB, uint8(0), 0);
            pause(0.01); % kv.dur-onsetChange-0.02
        end

    end
    
    v.quit();
    
    if flags.do_debugMode
    debugRect = [10 10 200 200];
    [win,winRect] = Screen('OpenWindow',kv.screenNumber,black,debugRect);
    ShowCursor;
    else
        [win,winRect] = Screen('OpenWindow',kv.screenNumber, black);
    end

    Screen('TextSize',win, 20);
    [screenXpix,screenYpix] = Screen('WindowSize', win);
    [x_center,y_center] = RectCenter(winRect);
    
    DrawFormattedText(win,instructionA,.2*x_center,'center',white,120,0,0,1.5);
    Screen('Flip',win);
    pause(2);
    
end

%% Test procedure
pause(1)
% wait for space key
keyCode(spaceKey) = 0;
while keyCode(spaceKey) == 0
    [secs, keyCode] = KbWait;
end

% initialize response variables
subj.E = nan(length(subj.trials(:,1)),1); % relative externalization response: closer (-1), farther (1)
subj.RT = nan(length(subj.trials(:,1)),1); % reaction time
subj.hit = nan(length(subj.trials(:,1)),1); % hits

if flags.do_eeg
    IOPort('Write', TB, uint8(trigVals.startBlock), 0);
    pause(0.01);
    IOPort('Write', TB, uint8(0), 0);
    pause(0.01);
end

pause(1.5)  % add a pause to ensure the pause is active before the sound 


% Fixation point
Screen('DrawDots',win, [x_center,y_center], 14, white, [], 2);
Screen('Flip',win);
pause(1)

% presentation of trials
for n = 1:length(subj.trials(:,1))
    
    % if the trial is a looming trial -> then the contrast reference of the first
    % signal (c1) is 1 or 2 depending on whether it is a
    % native/inverted condition -> 1/2 references the row of the stim.sig
    % table, where stim.sig(1,:)=1 stim.sig(2,:)=-1 stim.sig(3,:)=0
    % vice versa with receding trials
    %
    % stim crossover is always c1 -> c2
    % 1 -> 0 is looming native
    % 0 -> 1 is receding native
    % -1 -> 0 is looming inverted
    % 0 -> -1 is receding inverted
    
    if subj.trials(n,1) == -1
        if subj.trials(n,2) == -1
            c1 = 2;
            c2 = 3;
        else
            c1 = 3;
            c2 = 2;
        end
    else
        if subj.trials(n,2) == -1
            c1 = 1;
            c2 = 3;
        else 
            c1 = 3;
            c2 = 1;
        end
    end
    
    pp=subj.trials(n,3); % position of loudspeaker (37 or 82)
    ff=subj.trials(n,9); % frequenz of stimulus - one of 12 different freqs -> 3rd dimension in stim.sig

    % combine stimulus pairs with temporal jitter of crossfade
    % and save the respective jitter in the trialList to make it accessible
    % later
    dt = kv.jitter*(rand-0.5);
    subj.tempJ(n,1) = dt;
    % time for onset second stimulus
    onsetChange = kv.dur/2+dt-kv.xFadeDur/2;

    [sigpair,nM2] = Born2Hear_crossfade(stim.sig{c1,pp,ff},stim.sig{c2,pp,ff},...
    stim.fs,kv.dur,kv.dur/2+dt,kv.xFadeDur,'argimport',flags,kv);

%     % Plot spectral maps to check stimuli
%     if flags.do_debugMode
%       % Plot spectrograms
%       figSgram = figure;
%       subplot(2,2,1)
%       sgram(sigpair(:,1),kv.fs,'dynrange',60,'db')
%       title('Left')
%       subplot(2,2,2)
%       sgram(sigpair(:,2),kv.fs,'dynrange',60,'db')
%       title('Right')
%       subplot(2,2,3)
%       plot(sigpair(:,1))
%       xlim([1.4e4 4.3e4])
%       ylim([-0.1 0.1])
%       title('Left')
%       subplot(2,2,4)
%       plot(sigpair(:,2))
%       xlim([1.4e4 4.3e4])
%       ylim([-0.1 0.1])
%       title('Right')
%       % Display trial values
%       table(subj.trials(n,1:3),dt)
%     end

    % playback
    if flags.do_eeg % with StimTrak
        PsychPortAudio('FillBuffer', pahandle, [sigpair stimVec]');
    else
        PsychPortAudio('FillBuffer', pahandle, sigpair');
    end
    tic;
    PsychPortAudio('Start', pahandle, 1, 0, 1);

    % trigger: timestamp for onset/change & exp. condition (1-32)
    if flags.do_eeg 
        IOPort('Write', TB, uint8(subj.trials(n,7)), 0);
        pause(0.01);
        IOPort('Write', TB, uint8(0), 0);
        pause(onsetChange-0.01); % wait until start of crossfade

        IOPort('Write', TB, uint8(subj.trials(n,8)), 0);
        pause(0.01);
        IOPort('Write', TB, uint8(0), 0);
        pause(0.01); % kv.dur-onsetChange-0.02
    end

    if flags.do_beh
        pause(onsetChange)
    end

    % Get response via keyboard 
    keyCodeVal = 0;
    
    while not(any(keyCodeVal==[closerKey,fartherKey]))
    [tmp,keyCode] = KbWait([],2);
    keyCodeVal = find(keyCode,1);
    end
    respPress=toc;

    subj.RT(n) = respPress-onsetChange;

    % Externalization response
    if keyCodeVal == closerKey
      subj.E(n) = -1;
    elseif keyCodeVal == fartherKey
      subj.E(n) = 1;
    else
      subj.E(n) = nan;
    end

    % Relationship between D and E 
    subj.hit(n) = subj.E(n) == subj.D(n);

    % send trigger for E and hit/miss
    if flags.do_eeg
        if subj.hit(n) == 1
            if keyCodeVal == closerKey
                RespTrig = trigVals.closerHit;
            else
                RespTrig = trigVals.fartherHit;
            end
        else
             if keyCodeVal == closerKey
                RespTrig = trigVals.closerMiss;
             else 
                RespTrig = trigVals.fartherMiss;
            end       
        end
        IOPort('Write', TB, uint8(RespTrig), 0);
        pause(0.01);
        IOPort('Write', TB, uint8(0), 0);
        pause(0.01);
    end


     Screen('FillRect',win,black);
     Screen('Flip',win);
     % for responses during stimuliation, wait until end of stimulation
     if respPress < (kv.dur-onsetChange)
         pause(kv.dur-respPress-onsetChange)
     end
     pause(0.3)
     Screen('DrawDots',win, [x_center,y_center], 14, white, [], 2);
     Screen('Flip',win);         


    gt = kv.jitter*(rand-0.5);
    subj.tempJ(n,2) = gt;
    pause(0.5 + gt) % -> 0.8 (0.3 from above + 0.5) +/- 50 ms

%     if flags.do_debugMode
%       close(figSgram)
%     end

    % Intermediate score    
    subj.pcorrect = 100* nansum(subj.hit(1:n)) / n;  
    
    % break after half of trials
    if n == length(subj.trials(:,1))/2
        
        %trigger for block end
        if flags.do_eeg
          IOPort('Write', TB, uint8(trigVals.endBlock), 0);
          pause(0.01);
          IOPort('Write', TB, uint8(0), 0);
          pause(0.01);
        end
   
        % Save results
        save(savename,'subj')
        
        % Display time course
        infotext1 = [...
            'PAUSE',...
            '\n\n\n H?lfte geschafft!',...
            '\n\n\n Leertaste Taste dr??cken um mit dem Experiment fortzufahren.'];
        
        DrawFormattedText(win,infotext1,.2*x_center,'center',white,120,0,0,1.5);
        Screen('Flip',win);
        
        disp('Info given to listener:')
        disp(infotext1)
        % wait for space key press of subject, then start trigger for new
        % block
        keyCode(spaceKey) = 0;
        while keyCode(spaceKey) == 0
            [~, keyCode] = KbWait;
        end

        if flags.do_eeg
            IOPort('Write', TB, uint8(trigVals.startBlock), 0);
            pause(0.01);
            IOPort('Write', TB, uint8(0), 0);
            pause(0.01);
        end
        
        % Fixation point
        Screen('DrawDots',win, [x_center,y_center], 14, white, [], 2);
        Screen('Flip',win);
        pause(1)
            
    elseif n == length(subj.trials(:,1))        
        % Inform listener that experiment is completed if all trials are
        % finished
        infotext2 = [...
        '\n\n\n Vielen Dank! Das Experiment ist abgeschlossen.'];
        DrawFormattedText(win,[infotext2],'center','center',white);
        
        % Experimenter monitoring info (incl % correct)
        disp('Info given to listener:')
        disp(infotext2)
        disp([num2str(subj.pcorrect,'%3.2f'),'% richtige Antworten.'])
        
        Screen('Flip',win);
        WaitSecs(5);
        Screen('CloseAll');  
        
    end 
end


% Save results
save(savename,'subj')

% close PsychAudioPort and virtual  serial port
PsychPortAudio('Close', pahandle);
WaitSecs(3);
Screen('CloseAll');

if flags.do_eeg
    IOPort('Close', TB);
end

end
