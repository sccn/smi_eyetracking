function EEG = pop_read_smi(filedata, fileevent)

smi = read_smi_txt_with_events(filedata, fileevent);

% convert SMI to EEG structure including events
EEG = eeg_emptyset;

EEG.srate = smi.Fs;
EEG.data  = smi.dat;
EEG.pnts  = size(smi.dat,2);
EEG.nbchan = size(smi.dat,1);
EEG.trials = 1;
EEG = eeg_checkset(EEG);

% add the events - DEEPA, the events are in smi.event
% place them in EEG.event according to the EEGLAB event format
% conversion is necessary
% https://eeglab.org/tutorials/ConceptsGuide/Data_Structures.html#eegevent

% EEG.event = smi.event; % NO

% 1. Create evetns for fixation
% 2. Create evetns for sacaddes
% 3. Create evetns for blinks
% 4. Create evetns for userevents

% make sure the latency is in sample, with respect to the ebeigning of the
% data
% 
% ****************
% Fixation Event: search for the position of '2882391240' in the first
% column of the sample file. The one below would be below latency equals 7 samples
% ****************
%
%   struct with fields:
% 
%         EventType: 'Fixation L'
%             Trial: '1'
%            Number: '1'
%             Start: '2882391240'
%               End: '2882541195'