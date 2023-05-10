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
if nargin > 1 && ~isempty(fileevent)
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





function [eye_srate,event] = read_events(event_file)

fid = fopen(event_file, 'r');
fopen(fid);
if fid == -1
    error('Cannot open file')
end

j = 1; % iterator for event types (e.g. fixations, blinks, saccades etc.)
eye_srate = 0; % sampling rate
event = [];
event_types = {};
event_features = {};
while ~feof(fid)
    
    file_scan = fgetl(fid);
    
        % extract and store sampling rate of the eye tracking raw data
    if contains(file_scan,"Sample Rate:")
       eye_srate = split(file_scan,"Sample Rate:");
       eye_srate = str2double(eye_srate{2});
    elseif contains(file_scan,"Table Header for ")
        % fetch event type and corresponding features (column headers)
       event_types{j} = strrep(extractAfter(file_scan,"Table Header for "),':','');
       event_types{j} = regexprep(event_types{j}, ' +', '');
       file_scan = fgetl(fid);
       temp = split(file_scan,'  ');
       emptyCells = cellfun(@isempty,temp);
       temp(emptyCells) = [];       
       event_features{j} = lower(regexprep(temp, ' +', ''));
       event_features{j} = strrep(event_features{j},'.','');
       clear temp
       clear emptyCells
       j = j+1;
    elseif eye_srate>0 && any(regexp(file_scan,'[0-9]'))
        % fetch event values 
        [eventType,strOut] = strtok(file_scan);
        ix = strfind(event_types,eventType);
        ix = find(not(cellfun('isempty',ix)));
        % fetch event type value and store it in event.type
        [trial,strOut] = strtok(strOut);
        if isequal(trial, 'L') || isequal(trial, 'R')
            eventType = [ eventType trial];
            [trial,strOut] = strtok(strOut);
        end
        event(end+1).type =  eventType;
        temp = split(file_scan,'  ');
        emptyCells = cellfun(@isempty,temp);
        temp(emptyCells) = [];
        clear emptyCells
        % fetch all other values and store in the appropriate struct field
        for i=1:size(event_features{ix},1)
            if strcmp(event_features{ix}{i,1},'eventtype')
                continue
            elseif isnan(str2double(temp{i,1}))
                event(end).(event_features{ix}{i,1}) = temp{i,1};
            elseif strcmp(event_features{ix}{i,1},'start')
                event(end).latency =  str2double(temp{i,1});
            else
                event(end).(event_features{ix}{i,1}) = str2double(temp{i,1});
            end
        end
    end
end
fclose(fid);
return
