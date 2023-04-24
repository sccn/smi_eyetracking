function smi = read_smi_txt_with_events(filename, fileevent)

% READ_SMI_TXT_WITH_EVENTS reads the header information, input triggers, messages
% and all data points from an SensoMotoric Instruments (SMI) *.txt file
%
% Use as
%   smi = read_smi_txt(filename)

% Copyright (C) 2016, Diego Lozano-Soldevilla (CerCo), Deepa Gupta and Arnaud Delorme (2023)
%
% This file is derived from a file part of FieldTrip, see http://www.fieldtriptoolbox.org/

smi.header  = {};
smi.label   = {};
smi.dat     = [];
if nargin > 1
    [smi.EYETRACK,smi.event]   = read_events(fileevent);
else
    smi.event   = [];
end
current     = 0;

% read the whole file at once
fid = fopen(filename, 'rt');
if fid == -1
    error('Cannot open file')
end
aline = fread(fid, inf, 'char=>char');          % returns a single long string
fclose(fid);

aline(aline==uint8(sprintf('\r'))) = [];        % remove cariage return
aline = tokenize(aline, uint8(sprintf('\n')));  % split on newline

for i=1:numel(aline)
    tline = aline{i};

    if numel(tline) && any(tline(1)=='0':'9') && ~contains(tline, 'Message')
        % if regexp(tline, '^[0-9]')
        tmp = regexp(tline,'[^\t\r\n\f\v]*','match')';
        % exclude SMP sting
        smp = regexp(tmp','SMP');
        smpidx = find(cellfun(@numel,smp)==1);

        current = current + 1;
        smi.type{1,current} =  sscanf(tmp{smpidx}, '%s');
        tmp(smpidx,:) = [];

        for j=1:size(tmp,1)
            val = sscanf(tmp{j,1}, '%f');
            if isempty(val)
                smi.dat(j,current) =  NaN;
            else
                smi.dat(j,current) =  val;
            end
        end

    elseif regexp(tline, '##')
        smi.header = cat(1, smi.header, {tline});

        template ='## Sample Rate:';
        if strncmp(tline,template,length(template))
            smi.Fs = cellfun(@str2num,regexp(tline,'[\d]+','match'));
        end

        template = '## Number of Samples:';
        if strncmp(tline,template,length(template))
            smi.nsmp = cellfun(@str2num,regexp(tline,'[\d]+','match'));
        end

        template = '## Head Distance [mm]:';
        if strncmp(tline,template,length(template))
            smi.headdist = cellfun(@str2num,regexp(tline,'[\d]+','match'));
        end

    elseif regexp(tline, 'Time*')
        smi.label = cat(1, smi.label, {tline});
        smi.label = regexp(smi.label{:},'[^\t\r\n\f\v]*','match')';
        typeln = regexp(smi.label','Type');
        typeidx = find(cellfun(@numel,typeln)==1);

        % delete Type column because only contains strings
        smi.label(typeidx,:) = [];
        % preamble data matrix
        smi.dat = zeros(size(smi.label,1),smi.nsmp);

    else
        % all other lines are not parsed
    end

end

% remove the samples that were not filled with real data
% smi.dat = smi.dat(:,1:current);

% place the timestamp channel outside of the data
c = find(strcmp(smi.label, 'Time'));
if numel(c)==1
    smi.timestamp = smi.dat(c,:);
    smi.dat(c,:) = [];
    smi.label(c) = [];
end









function [EYETRACK,event] = read_events(event_type)

EYETRACK = [];
fid = fopen(event_type, 'r');
fopen(fid);
if fid == -1
    error('Cannot open file')
end

for iRow = 1:29
    fgetl(fid);
end

event = [];
while ~feof(fid)
    row = fgetl(fid);
    [eventType,strOut] = strtok(row);
    [trial,strOut] = strtok(strOut);
    if isequal(trial, 'L') || isequal(trial, 'R')
        eventType = [ eventType trial];
        [trial,strOut] = strtok(strOut);
    end
    [number,strOut] = strtok(strOut);
    [latency,strOut] = strtok(strOut);

    event(end+1).type =  eventType;
    event(end).trial =  trial;
    event(end).number =  number;
    event(end).latency =  str2double(latency);
    switch eventType
        case 'UserEvent'
            event(end).type = [ event(end).type strtrim(strOut)];
            % case event_type{1}
            % special columns for saccades
    end
end
fclose(fid);
return




% if no string was entered or if the file doesn't exist then output error
if isempty(file) || ~isfile(file)
    fprintf("No event file found. Please enter a valid event filename");
    return
end

% extract filename and file format of raw eye tracking data
[filenameformat] = split(file,'.');
read_flag = 0;
% initial scan of the content based on the file format (tsv/txt/csv etc.)
try
    file_scan = readtable(file,'FileType', 'text');
catch ME
    fprintf(ME.message);
    read_flag = 1;
    %     return
end

if read_flag == 1
    file_scan = loadtxt(file);
    if (~isempty(file_scan))
        fprintf("\n file read. Parsing is under way.");
        return
    end
end
% go through the initial scan of the raw eye tracking raw file

if (isempty(file_scan))
    fprintf("\n file read error. please try another. Exiting for now");
    return
end

i = 1; % iterator for file scan rows
j = 1; % iterator for event types (e.g. fixations, blinks, saccades etc.)
event_type = {};
event_features = {};
event_values = {};
init_features = 0; % 0 = false, 1 = true % features initialized
EYETRACK = struct;
event_values = {};
eye_srate = 0;

while (i < size(file_scan,1))

    % extract and store sampling rate of the eye tracking raw data
    if contains(file_scan(i,1).(1){1},"Sample Rate:")
        eye_srate = split(file_scan(i,1).(1){1},"Sample Rate:");
        eye_srate = str2num(eye_srate{2});

        % extract event types and its headers from the eye tracking raw data
    elseif contains(file_scan(i,1).(1){1},"Table Header for ")
        event_type{j} = strrep(extractAfter(file_scan(i,1).(1){1},"Table Header for "),':','');
        i = i+1;
        temp = split(file_scan(i,1).(1){1},'  ');
        emptyCells = cellfun(@isempty,temp);
        temp(emptyCells) = [];
        event_features{j} = temp;
        clear temp
        clear emptyCells
        j = j+1;

        % extract values from the eye tracking raw file
    elseif eye_srate>0 && any(regexp(file_scan(i,1).(1){1},'[0-9]'))
        if ~init_features
            event_type = strrep(event_type,' ',''); %remove spaces
            for k = 1:size(event_features,2)
                event_features{k} = strrep(event_features{k},' ','');
            end
            %initialize event values storage for each feature
            event_values = cell(size(event_type));
            init_features = 1;
        else
            temp = split(file_scan(i,1).(1){1},'  ');
            emptyCells = cellfun(@isempty,temp);
            temp(emptyCells) = [];
            clear emptyCells
            % check which event description's values are retrieved and store
            % the obtained values for that event
            value_type = split(temp{1},' ');
            index = contains(event_type,value_type{1});
            clear value_type
            index = find(index,1);
            %            event_values{index}{end+1,1} = temp'; % <- issue, dont bother
            event_values{end+1,index} = temp';
            clear temp
        end
    end
    i = i+1;
end


EYETRACK.eye_srate = eye_srate;
for i = 1:size(event_type,2)
    values = reshape([event_values{:,i}],size(event_features{i},1),[])';
    if ~isempty(values)
        S = cell2struct([values],strrep(event_features{i},'.','')',2);
        EYETRACK = setfield(EYETRACK,event_type{i},S);
        clear S
    end
    clear values
end

%%
% EEG_timeperiod = EEG.events; % find the event end latency (not EEG.xmax)
EEG_timeperiod = 119; % for video 1 % extracted from EEG
EYETRACK.xmin = str2num(EYETRACK.UserEvents(1).Start);
EYETRACK.xmax = str2num(EYETRACK.UserEvents(2).Start);
EYETRACK.duration =  EYETRACK.xmax - EYETRACK.xmin;
EYETRACK.sample_step = EYETRACK.duration/EEG_timeperiod; % 1ms equivalent

for i = 1:size(EYETRACK.Fixations,1)
    EYETRACK.Fixations(i).Startms = (str2num(EYETRACK.Fixations(i).Start) - EYETRACK.xmin )/EYETRACK.sample_step;
    EYETRACK.Fixations(i).Endtms = (str2num(EYETRACK.Fixations(i).End) - EYETRACK.xmin )/EYETRACK.sample_step;
end
for i = 1:size(EYETRACK.Saccades,1)
    EYETRACK.Saccades(i).Startms = (str2num(EYETRACK.Saccades(i).Start) - EYETRACK.xmin )/EYETRACK.sample_step;
    EYETRACK.Saccades(i).Endms = (str2num(EYETRACK.Saccades(i).End) - EYETRACK.xmin )/EYETRACK.sample_step;
end
for i = 1:size(EYETRACK.Blinks,1)
    EYETRACK.Blinks(i).Startms = (str2num(EYETRACK.Blinks(i).Start) - EYETRACK.xmin )/EYETRACK.sample_step;
    EYETRACK.Blinks(i).Endms = (str2num(EYETRACK.Blinks(i).End) - EYETRACK.xmin )/EYETRACK.sample_step;
end

eye_events = fieldnames(EYETRACK);
events_fields = {'type','latency'};
events_count = 0;
event = struct;
for i = 1:length(eye_events)
    if isstruct(EYETRACK.(eye_events{i}))
        temp = EYETRACK.(eye_events{i});
        latency = {(temp.Start)}';
        % convert timestamp of string type to numeric value
        latency = cellfun(@str2num,latency,'un',0);
        % if event type is plural, make it singular for the event structure
        type = repmat({eye_events{i}}, length(EYETRACK.(eye_events{i})), 1);
        data = horzcat(type,latency);
        temp_events = cell2struct(data,events_fields,2);
        events_count = events_count+1;
        if events_count>1
            event = [event; temp_events];
        else
            event = temp_events;
        end
        clear temp
        clear latency
        clear data
        clear temp_events
    end

end
