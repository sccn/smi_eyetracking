function EEG = pop_read_smi(filedata, fileevent)

if nargin < 2 || isempty(fileevent)
    fileevent = [ filedata(1:end-11) 'Events.txt' ];
    tmp = dir(fileevent);
    if isempty(tmp)
        fileevent = [];
    end
end

smi = read_smi_txt_with_events(filedata, fileevent);

% convert SMI to EEG structure including events
EEG = eeg_emptyset;

EEG.srate = smi.Fs;
EEG.data  = smi.dat;
EEG.pnts  = size(smi.dat,2);
EEG.nbchan = size(smi.dat,1);
EEG.trials = 1;
EEG.chanlocs = struct('labels', smi.label);
EEG = eeg_checkset(EEG);

% add the events - DEEPA, the events are in smi.event
% place them in EEG.event according to the EEGLAB event format
% conversion is necessary
% https://eeglab.org/tutorials/ConceptsGuide/Data_Structures.html#eegevent

timeInc = median(diff(smi.timestamp));
realSampleRate = 1000000/timeInc;
firstSampleLat = smi.timestamp(1);
if abs(realSampleRate-smi.Fs) > 1
    fprintf(2,'Issue with sample rate, file says %1.2f, sample say %1.2f\n', smi.Fs, realSampleRate)
end

if isfield(smi, 'event')
    EEG.event = smi.event;
    for iEvent = 1:length(EEG.event)
        EEG.event(iEvent).latency_ori = EEG.event(iEvent).latency;
        EEG.event(iEvent).latency     = (EEG.event(iEvent).latency-firstSampleLat)/timeInc+1;
        if ~isempty(EEG.event(iEvent).description) && contains(EEG.event(iEvent).description, '# Message: ')
            EEG.event(iEvent).description = EEG.event(iEvent).description(12:end);
        end
    end        
end
EEG = eeg_checkset(EEG, 'eventconsistency');
