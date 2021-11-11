function Born2Hear_WP1ctr(ID,varargin)
%% runs Born2Hear experiment
%
% variables
% Direction (D): looming (-1) or receding (1) or static (0); col 3
% Continuity (cont): continuous (1) or gap (-1); col 4 OR change (0) vs. static (-1 for near, 1 for far) for design = 'static'
% Type of spectral profile: native (1) or inverted (-1); col 5 + add.
% 
%
% E (externalized response): closer (-1) or farther (1)
% hit: correct response (1) or wrong response (0)

%% start deleting everything
saveFileNamePrefix = 'Exp1';

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
savename = fullfile('data',[saveFileNamePrefix '_' subj.ID]);

if not(exist('./data','dir'))
  mkdir('data')
end

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
    savepath = fullfile('\\W07kfs4\eap\Resources\Experimental_Data\Main Experiments\NH',name,'Born2Hear\WP1_ctr');
    
    if not(exist(savepath))
      mkdir(savepath)
    end
    
    savename = fullfile(savepath,[saveFileNamePrefix '_' subj.ID]);
end
%% Internal seetings
KbName('UnifyKeyNames');

spaceKey = KbName('Space');

closerKey = KbName('UpArrow');
fartherKey = KbName('DownArrow');

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

%         Block	trigOnset	trigChange
%         plc	127 + cell	159 + cell
%         pli	127 + cell	159 + cell
%         prc	135 + cell	167 + cell
%         pri	135 + cell	167 + cell
%         alc	143 + cell	175 + cell
%         ali	143 + cell	175 + cell
%         arc	151 + cell	183 + cell
%         ari	151 + cell	183 + cell

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
    TB = IOPort('OpenSerialPort', 'COM3'); % replace ? with number of COM port
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
       'Sie werden nun für ca. 25 min einen Film mit Untertitel ohne Tonspur sehen. Ihre Aufgabe ist es, sich NUR auf den Film zu konzentrieren, und die Geräusche zu ignorieren. ',...
       'Am Ende werden Ihnen Fragen zum Film gestellt.\n\n',...
       'Bitte versuchen Sie, sich während des Films möglichst wenig zu bewegen!\nNach je 8 min pausiert der Film und Sie können eine Pause einlegen.\n\n',...
       'Sollten die Geräusche unangenehm laut sein, bitte sofort der Versuchsleitung Bescheid geben.\n\n',...
       'Haben Sie noch Fragen?\n\n',...
       'Zum Starten die Leertaste drücken.'];
end

%% Listener instruction active part
instructionA = [...
  'In diesem Experiment hören Sie Paare aus zwei Geräuschen. Konzentrieren Sie sich nur auf deren Unterschied bezüglich \n',... 
  'räumlicher ENTFERNUNG (relativ zur Mitte Ihres Kopfes gesehen). \n',...
  'Versuchen Sie andere Unterschiede wie räumliche Höhe, Intensität oder Tonhöhe zu ignorieren. \n',...
  '\n',...
  'Manchmal scheinen die Geräusche von einer bestimmten Stelle rechts hinter Ihnen im Raum zu kommen, \n',...
  'und manchmal scheint es, als kämen sie aus der Nähe ihres Kopfes oder sogar aus dem Inneren Ihres Kopfes. \n',...
  '\n',...
  'Ihre Aufgabe während des Experiments ist es...\n',...
  '   den linken Pfeil zu drücken, wenn das ZWEITE Geräusch NÄHER an ihrem Kopf erscheint als das erste \n',...
  '   den rechten Pfeil zu drücken, wenn das ZWEITE Geräusch ENTFERNTER von ihrem Kopf erscheint als das erste \n'];

instructionA = [instructionA,...
  '\nEs gibt auch Blöcke, wo die Geräusche anstatt von schräg rechts, von schräg links kommmen. \n',...
  'Auch hier ist das zweite Geräusch manchmal näher, weiter entfernt, oder gleich wie das erste. \n',...
  '\n',...
  'Ihre Aufgabe während des Experiments (Geräusche von links) ist es...\n',...
  '   die Taste C zu drücken, wenn das ZWEITE Geräusch NÄHER an ihrem Kopf erscheint als das erste \n',...
  '   die Taste  Y zu drücken, wenn das ZWEITE Geräusch ENTFERNTER von ihrem Kopf erscheint als das erste \n'];

instructionA = [instructionA,...
  '\n',...
  'Antworten Sie so schnell wie möglich!\n\n',...
  'Bitte richten Sie Ihren Blick während der Geräuschwiedergabe stets auf den weißen Punkt in der Mitte des Bildschirms. \n'];
if flags.do_lateResp
    instructionA=[instructionA,...
  'Antworten Sie erst, nachdem sich der Punkt blau gefärbt hat (nach Ende des zweiten Geräusches).\n'];
end
instructionA= [instructionA,...
   'Nach kurzen Blöcken von je 3 Minuten haben Sie die Möglichkeit eine Pause einzulegen.\n\n'];

if flags.do_beh
    instructionA=[instructionA,...
    'Sollten die Geräusche unangenehm laut sein, geben Sie bitte sofort der Versuchsleitung Bescheid! \n',...
    '\n'];
end
instructionA= [instructionA,...
    'Bevor das Experiment beginnt, hören Sie ein paar Tonbeispiele, um die Aufgabe zu üben. \n'];

instructionA=[instructionA,...
  'Haben Sie noch Fragen? \n',...
  'Zum Starten '];
if flags.do_familiarize
    instructionA=[instructionA,...
    'der Übungsdurchgänge '];
end
instructionA=[instructionA,...
   'bitte die Leertaste drücken.'];

DrawFormattedText(win,instructionA,.2*x_center,'center',white,120,0,0,1.5);
Screen('Flip',win);

%% load stimuli and positions

if flags.do_laptop
    load(fullfile('data',['stimuli_' ID]));
else
    load(fullfile(savepath,['stimuli_' ID]));
end

%% Create trial list
% t1 : 4x native (1) and 4x inverted (-1) 
% t2 : 4x looming (-1) and 4x receding (1)
% t3 : 2 LASpos (left 37 & right 82) 4 times (once for each direction & each contrast
% condition -> reference to column in stim.sig
% looming/receding, native/inverted and LASpos are cross-referenced such
% that each stimulus is played once from every position 

% t4 : lateralization of each speaker position (left 1, right -1)
% t5 : 
% t6 :
% t7 : frequency of stim (12 different freqs) -> reference to 3rd dimension
% in stim.sig

t1=repelem([-1,1],4)'; 
t2=repelem([-1,1,-1,1],2)';
t3=repmat([37,82],1,4)';
t4=repmat([1,-1],1,4)';

% trigger at onset
% calculation of a different trigger depending on whether the signal is
% native/inverted ; looming/receding
for n = 1:length(t1)
    if t1(n) == -1 && t2(n) == -1
        t5(n) = 1;
    elseif t1(n) == -1 && t2(n) == 1
        t5(n)= 2;
    elseif t1(n) == 1 && t2(n) == -1
        t5(n)= 3;
    elseif t1(n) == 1 && t2(n) == 1
        t5(n)= 4;
    end
end

% calculation of different trigger for left/right
for n = 1:length(t4)
    if t4(n) == 1
        t5(n)=t5(n)+8;
    end
end

% trigger at change
% calculation of a different trigger depending on whether the signal is
% native/inverted ; looming/receding
for n = 1:length(t1)
    if t1(n) == -1 && t2(n) == -1
        t6(n) = 5;
    elseif t1(n) == -1 && t2(n) == 1
        t6(n)= 6;
    elseif t1(n) == 1 && t2(n) == -1
        t6(n)= 7;
    elseif t1(n) == 1 && t2(n) == 1
        t6(n)= 8;
    end
end

% calculation of different trigger for left/right
for n = 1:length(t4)
    if t4(n) == 1
        t6(n)=t6(n)+8;
    end
end

% create trial table from vectors t1 to t5 (corresponding to 1 repetition!)
trialList = [t1,t2,t3,t4,t5,t6];
% repeat matrix 50 times (such that the list contains 100 trials
% respectively for inverted & native conditions on the left and the right
trialList = repmat(trialList,50,1); 

% frequencies
t7=repelem([1:kv.Fr],ceil(length(trialList)/kv.Fr));
t7=t7(randperm(length(t7)))';
trialList(:,7)=t7(1:length(trialList));

% randomize the trialList & then sort trials such that left/right trials
% are blocked (whether left or right comes first is also randomized) + such
% that inverted/native trials are blocked (inverted always precedes native to minimize bias)

randomized_dummy = trialList(randperm(size(trialList, 1)), :);
contrast_sorted = sortrows(randomized_dummy, 1);

lr = randi([1,2]);
if lr == 1
    sorted_dummy = sortrows(contrast_sorted, 3, {'ascend'});
else
    sorted_dummy = sortrows(contrast_sorted, 3, {'descend'});
end

% the final trial list is a randomization of the trialList table
subj.trials = sorted_dummy;

% Set values
subj.D = subj.trials(:,1); % 1st column: looming (-1) or receding (1)
subj.pos = subj.trials(:,3); % speaker positions (37 left or 82 right)

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
    % 0 -> -1 is looming inverted
    % -1 -> 0 is receding inverted

        if subj.trials(n,1) == -1
            if subj.trials(n,2) == -1
                c1 = 3;
                c2 = 2;
            else
                c1 = 2;
                c2 = 3;
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

        pp=subj.trials(n,3); % position of loudspeaker (37 left or 82 right)
        ff=subj.trials(n,7); % frequenz of stimulus - one of 12 different freqs -> 3rd dimension in stim.sig

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
        
        infotext = [infotext,...
           'PAUSE',...
           '\n\n\n H�lfte des Videos abgeschlossen. Bitte Leertaste Taste drücken um mit dem Video fortzufahren.'];

        if n == length(subj.trials(:,1))/2
            pause(1.2)
            % pause video
            v.pause();
            % Experimenter monitoring info
            disp('Info given to listener:')
            disp(infotext)
            % force break
            % pause(10)
            keyCode(spaceKey) = 0;
            while keyCode(spaceKey) == 0
                [secs, keyCode] = KbWait;
            end
            % resume video
            v.play();

            % start trigger for new block
            IOPort('Write', TB, uint8(trigVals.startBlock), 0);
            pause(0.01);
            IOPort('Write', TB, uint8(0), 0);
            pause(0.01);
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
    % 0 -> -1 is looming inverted
    % -1 -> 0 is receding inverted
    
    if subj.trials(n,1) == -1
        if subj.trials(n,2) == -1
            c1 = 3;
            c2 = 2;
        else
            c1 = 2;
            c2 = 3;
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
    
    pp=subj.trials(n,3); % position of loudspeaker (37 left or 82 right)
    ff=subj.trials(n,7); % frequenz of stimulus - one of 12 different freqs -> 3rd dimension in stim.sig

    % combine stimulus pairs with temporal jitter of crossfade
    % and save the respective jitter in the trialList to make it accessible
    % later
    dt = kv.jitter*(rand-0.5);
    subj.tempJ(n,1) = dt;
    % time for onset second stimulus
    onsetChange = kv.dur/2+dt-kv.xFadeDur/2;

    [sigpair,nM2] = Born2Hear_crossfade(stim.sig{c1,pp,ff},stim.sig{c2,pp,ff},...
    stim.fs,kv.dur,kv.dur/2+dt,kv.xFadeDur,'argimport',flags,kv);

    % Plot spectral maps to check stimuli
    if flags.do_debugMode
      % Plot spectrograms
      figSgram = figure;
      subplot(2,2,1)
      sgram(sigpair(:,1),kv.fs,'dynrange',60,'db')
      title('Left')
      subplot(2,2,2)
      sgram(sigpair(:,2),kv.fs,'dynrange',60,'db')
      title('Right')
      subplot(2,2,3)
      plot(sigpair(:,1))
      xlim([1.4e4 4.3e4])
      ylim([-0.1 0.1])
      title('Left')
      subplot(2,2,4)
      plot(sigpair(:,2))
      xlim([1.4e4 4.3e4])
      ylim([-0.1 0.1])
      title('Right')
      % Display trial values
      table(subj.trials(n,1:3),dt)
    end

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
        IOPort('Write', TB, uint8(subj.trials(n,5)), 0);
        pause(0.01);
        IOPort('Write', TB, uint8(0), 0);
        pause(onsetChange-0.01); % wait until start of crossfade

        IOPort('Write', TB, uint8(subj.trials(n,6)), 0);
        pause(0.01);
        IOPort('Write', TB, uint8(0), 0);
        pause(0.01); % kv.dur-onsetChange-0.02
    end


    if flags.do_lateResp
        if flags.do_eeg
            pause(kv.dur-onsetChange-0.02) % pause only from crossfade trigger to offset
        else
            pause(kv.dur)
        end
        Screen('DrawDots',win, [x_center,y_center], 14, blue, [], 2);
        Screen('Flip',win);
    else
        if flags.do_beh
            pause(onsetChange)
        end
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


     if flags.do_lateResp
         Screen('DrawDots',win, [x_center,y_center], 14, white, [], 2);
         Screen('Flip',win);
         pause(0.3)
     else
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

    gt = kv.jitter*(rand-0.5);
    subj.tempJ(n,2) = gt;
    pause(0.5 + gt) % -> 0.8 (0.3 from above + 0.5) +/- 50 ms

    if flags.do_debugMode
      close(figSgram)
    end
    
    if mod(n,91) == 0 % make break
        
        %trigger for block end
        if flags.do_eeg
          IOPort('Write', TB, uint8(trigVals.endBlock), 0);
          pause(0.01);
          IOPort('Write', TB, uint8(0), 0);
          pause(0.01);
        end
   
        % Intermediate score
        subj.pcorrect = 100* nansum(subj.hit(1:n)) / n;
        % Save results
        save(savename,'subj')
        
        % Display time course and intermediate score
        infotext = [...
            'PAUSE',...
            '\n\n\n',num2str(n/2) ' von ' num2str(length(subj.trials(:,1))/2) ' Blöcken abgeschlossen.'];
        % Inform listener that experiment is completed if all trials are
        % finished
        if n == length(subj.trials(:,1))
            infotext = [infotext,...
            '\n\n\n Vielen Dank! Das Experiment ist abgeschlossen.'];
            DrawFormattedText(win,[infotext],'center','center',white);
            Screen('Flip',win);
            WaitSecs(5);
            Screen('CloseAll');  
        % else continuation with experiment
        else
            infotext = [infotext,...
            '\n\n\n Leertaste Taste drücken um mit dem Experiment fortzufahren.'];
            DrawFormattedText(win,infotext,'center','center',white);
            Screen('Flip',win);
        end
        
        % Experimenter monitoring info (incl % correct)
        disp('Info given to listener:')
        disp(infotext)
        disp(num2str(subj.pcorrect,'%3.2f'),'% richtige Antworten.')
        % force break
        % pause(10)
        keyCode(spaceKey) = 0;
        while keyCode(spaceKey) == 0
            [~, keyCode] = KbWait;
        end
        
        % if experiment is not completed, start trigger for new block
        if n ~= length(subj.trials(:,1))
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
        end    
    end
end


% Save results
save(savename,'subj')

% close PsychAudioPort and virtual  serial port
PsychPortAudio('Close', pahandle);

if flags.do_eeg
    IOPort('Close', TB);
end
