%% Born2Hear_runExp1

% cd C:\Users\dbaier\Documents\MATLAB\Born2Hear_Exp1;

cd C:\Users\rpfennigschmidt\Documents\GitHub\looming_bachelor;

clear all;
close all;
sca;

%% Listener-specific settings
ID = 'NH983';

if isempty(ID)
  ID = upper(input('Enter subject ID: ','s'));
end

%% Load dependencies
addpath(fullfile('..','stimulus')) 
addpath(fullfile('..','SOFA','API_MO'))
addpath(fullfile('..','ltfat'))
addpath(fullfile('..','amt'))

ltfatstart
SOFAstart
amt_start
sca
   
%% General settings for (EEG monitored) experiment 
familiarization = 'skipFamil'; %familiarize skipFamil

response = 'instantResp'; % lateResp
psychtoolbox = 'debugMode'; % fullscreen debugMode
soundOutput = 'laptop'; % lab laptop          
depVar = 'beh'; % eeg beh

stimGener = 'new'; % mytest new

soundType = 'schroeder'; % schroeder noise
HRTFs = 'genHRTF'; % yellowHRTF, lasHRTF, other1HRTF, other2HRTF, genHRTF

%% To be adjusted settings for every subject
order = 'SI'; % SI, IS
aziOrder = 'LR'; % RL or LR

%% Start (EEG monitored) experiment 

% determine azimuth angles acc to aziOrder code
switch aziOrder
    case 'RL'
          azi = [270,90];
    case 'LR'
        azi = [90,270];
end
% see arg_Born2Hear for all other default parameters

Born2Hear_Exp1(ID,familiarization,response,HRTFs,psychtoolbox,soundOutput,depVar,stimGener,order,soundType)
 