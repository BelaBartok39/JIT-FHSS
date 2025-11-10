%% JIT-FHSS Animated Visualization
% Real-time animation of the satellite communication system with live math values
% Controls:
%   SPACEBAR - Pause/Resume animation
%   UP/DOWN ARROWS - Increase/Decrease speed
%   Q - Quit animation

clear; close all; clc;

fprintf('=== JIT-FHSS Animated Visualization ===\n\n');

%% Load Simulation Results
addpath('src/');

if ~exist('results/simulation_results.mat', 'file')
    error('No simulation results found. Run run_simulation.m first.');
end

load('results/simulation_results.mat');
fprintf('Loaded simulation results.\n');
fprintf('Preparing animation with %d data points...\n\n', length(results.satelliteLog));

%% Extract Data
satelliteLog = results.satelliteLog;
receiverLog = results.receiverLog;
params = results.parameters;

% Time vectors
times = [satelliteLog.time];
txFreqs = [satelliteLog.transmitFreq];
rxFreqs = [satelliteLog.receivedFreq];
dopplerShifts = [satelliteLog.dopplerShift];
ranges = [satelliteLog.range];
rangeRates = [satelliteLog.rangeRate];
rxSuccess = [receiverLog.success];

%% Setup Orbital Model
orbit = OrbitModel(params.altitude, 98, 0, 0);
earthRadius = 6371; % km
satAltitude = params.altitude;

%% Animation Parameters
animData = struct();
animData.speedMultiplier = 20; % Start at 20x speed (slower to see details)
animData.frameSkip = 1; % Update every data point for smooth animation
animData.paused = false;
animData.quit = false;

% Start animation BEFORE first visibility to see satellite enter window
% Look back 30 seconds before first transmission
startIndex = max(1, find(~isnan([satelliteLog.range]), 1, 'first') - 300);
fprintf('Starting animation at index %d to show visibility window entry...\n', startIndex);

%% Create Figure
fig = figure('Position', [50, 50, 1400, 900], 'Color', 'k', ...
             'Name', 'JIT-FHSS Animation');
set(fig, 'UserData', animData);

%% Create 3D Earth View (Top portion)
ax3d = axes('Position', [0.05, 0.35, 0.6, 0.6], 'Color', 'k');
hold(ax3d, 'on');
axis(ax3d, 'equal');
grid(ax3d, 'off');
axis(ax3d, 'off');
view(ax3d, 45, 30);

% Draw Earth sphere
[X, Y, Z] = sphere(50);
earthSurface = surf(ax3d, X*earthRadius, Y*earthRadius, Z*earthRadius);
set(earthSurface, 'FaceColor', [0.2, 0.4, 0.8], 'EdgeColor', 'none', ...
    'FaceAlpha', 0.9, 'FaceLighting', 'gouraud');

% Add lighting
light('Position', [1, 0.5, 1], 'Style', 'infinite');
material(ax3d, 'dull');

% Draw orbital path
theta = linspace(0, 2*pi, 100);
orbitRadius = earthRadius + satAltitude;
orbitX = orbitRadius * cos(theta);
orbitY = orbitRadius * sin(theta) * cos(deg2rad(98));
orbitZ = orbitRadius * sin(theta) * sin(deg2rad(98));
plot3(ax3d, orbitX, orbitY, orbitZ, 'w--', 'LineWidth', 1, 'Color', [0.5, 0.5, 0.5, 0.3]);

% Ground station marker (at equator)
gsRadius = earthRadius + 10; % Slightly above surface
gsMarker = plot3(ax3d, gsRadius, 0, 0, 'g^', 'MarkerSize', 15, ...
                 'MarkerFaceColor', 'g', 'LineWidth', 2);

% Satellite marker
satMarker = plot3(ax3d, 0, 0, 0, 'ro', 'MarkerSize', 12, ...
                  'MarkerFaceColor', 'r', 'LineWidth', 2);

% Communication beams (will be updated)
% Pattern distribution beams (thinner, dashed)
beamCentralToSat = plot3(ax3d, [0, 0], [0, 0], [0, 0], 'c--', 'LineWidth', 1.5);
beamCentralToGS = plot3(ax3d, [0, 0], [0, 0], [0, 0], 'm--', 'LineWidth', 1.5);

% Data transmission beam (thick, will pulse)
beamSatToGS = plot3(ax3d, [0, 0], [0, 0], [0, 0], 'y-', 'LineWidth', 5);

% Add beam data flow indicators (small spheres that move along beam)
dataFlowMarker1 = plot3(ax3d, 0, 0, 0, 'yo', 'MarkerSize', 10, 'MarkerFaceColor', 'y');
dataFlowMarker2 = plot3(ax3d, 0, 0, 0, 'yo', 'MarkerSize', 8, 'MarkerFaceColor', 'y');
dataFlowMarker3 = plot3(ax3d, 0, 0, 0, 'yo', 'MarkerSize', 6, 'MarkerFaceColor', 'y');

% Central source indicator (off Earth)
centralSourcePos = [earthRadius*1.5, 0, -earthRadius*0.5];
plot3(ax3d, centralSourcePos(1), centralSourcePos(2), centralSourcePos(3), ...
      'ws', 'MarkerSize', 20, 'MarkerFaceColor', 'w', 'LineWidth', 2);
text(ax3d, centralSourcePos(1)+500, centralSourcePos(2), centralSourcePos(3), ...
     'Central Source', 'Color', 'w', 'FontSize', 10, 'FontWeight', 'bold');

xlim(ax3d, [-orbitRadius*1.5, orbitRadius*1.5]);
ylim(ax3d, [-orbitRadius*1.5, orbitRadius*1.5]);
zlim(ax3d, [-orbitRadius*1.5, orbitRadius*1.5]);

title(ax3d, 'JIT-FHSS Satellite Communication System', 'Color', 'w', ...
      'FontSize', 14, 'FontWeight', 'bold');

%% Create Info Panel (Bottom left)
axInfo = axes('Position', [0.05, 0.05, 0.4, 0.25], 'Color', 'k', 'XTick', [], 'YTick', []);
xlim(axInfo, [0, 1]);
ylim(axInfo, [0, 1]);
hold(axInfo, 'on');

% Text objects for live data
txtTime = text(axInfo, 0.05, 0.95, '', 'Color', 'w', 'FontSize', 11, 'FontWeight', 'bold');
txtRange = text(axInfo, 0.05, 0.85, '', 'Color', 'cyan', 'FontSize', 10);
txtRangeRate = text(axInfo, 0.05, 0.75, '', 'Color', 'cyan', 'FontSize', 10);
txtElevation = text(axInfo, 0.05, 0.65, '', 'Color', 'cyan', 'FontSize', 10);
txtTxFreq = text(axInfo, 0.05, 0.55, '', 'Color', 'yellow', 'FontSize', 10);
txtDoppler = text(axInfo, 0.05, 0.45, '', 'Color', 'magenta', 'FontSize', 10);
txtRxFreq = text(axInfo, 0.05, 0.35, '', 'Color', 'yellow', 'FontSize', 10);
txtCompFreq = text(axInfo, 0.05, 0.25, '', 'Color', 'green', 'FontSize', 10);
txtSuccess = text(axInfo, 0.05, 0.15, '', 'Color', 'w', 'FontSize', 10, 'FontWeight', 'bold');
txtBuffer = text(axInfo, 0.05, 0.05, '', 'Color', 'w', 'FontSize', 9);

title(axInfo, 'Live System Values', 'Color', 'w', 'FontSize', 12, 'FontWeight', 'bold');

%% Create Frequency Hopping Chart (Bottom right)
axFreq = axes('Position', [0.55, 0.05, 0.4, 0.25], 'Color', 'k');
hold(axFreq, 'on');
xlim(axFreq, [0, 50]); % Show last 50 seconds
ylim(axFreq, [params.frequencyBand(1)/1e6, params.frequencyBand(2)/1e6]);
xlabel(axFreq, 'Time (s)', 'Color', 'w');
ylabel(axFreq, 'Frequency (MHz)', 'Color', 'w');
title(axFreq, 'Frequency Hopping Pattern', 'Color', 'w', 'FontSize', 12);
set(axFreq, 'XColor', 'w', 'YColor', 'w', 'GridColor', 'w', 'GridAlpha', 0.3);
grid(axFreq, 'on');

freqPlot = plot(axFreq, [], [], 'g.', 'MarkerSize', 8);

%% Create Status Bar (Top right)
axStatus = axes('Position', [0.70, 0.85, 0.25, 0.10], 'Color', 'k', ...
                'XTick', [], 'YTick', []);
xlim(axStatus, [0, 1]);
ylim(axStatus, [0, 1]);
hold(axStatus, 'on');

txtStatus = text(axStatus, 0.5, 0.7, 'RUNNING', 'Color', 'g', ...
                 'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
txtSpeed = text(axStatus, 0.5, 0.4, sprintf('Speed: %dx', animData.speedMultiplier), ...
                'Color', 'w', 'FontSize', 11, 'HorizontalAlignment', 'center');
txtControls = text(axStatus, 0.5, 0.1, 'SPACE=Pause | ↑↓=Speed | Q=Quit', ...
                   'Color', [0.7, 0.7, 0.7], 'FontSize', 8, ...
                   'HorizontalAlignment', 'center');

% Set keyboard callback with access to text objects
set(fig, 'KeyPressFcn', @(src, event) keyPressCallback(src, event, txtStatus, txtSpeed));

%% Animation Loop
fprintf('Starting animation...\n');
fprintf('Controls: SPACEBAR=Pause | UP/DOWN=Speed | Q=Quit\n\n');

i = startIndex;
freqHistory = [];
timeHistory = [];
frameCount = 0; % For pulsing effects

while i <= length(times) && ishandle(fig)
    animData = get(fig, 'UserData');
    if animData.quit
        break;
    end

    if ~animData.paused
        frameCount = frameCount + 1;

        % Get current state
        currentTime = times(i);
        [satPos, ~] = orbit.getSatelliteState(currentTime);
        [range, rangeRate] = orbit.getRangeToGroundStation(currentTime);
        elevation = orbit.getElevationAngle(currentTime);
        visible = orbit.isVisible(currentTime, 5);

        txFreq = txFreqs(i);
        dopplerShift = dopplerShifts(i);
        rxFreq = rxFreqs(i);
        success = rxSuccess(i);

        % Calculate compensated frequency
        compFreq = rxFreq - dopplerShift;

        % Calculate Doppler alpha (0-1 based on magnitude)
        maxDoppler = 50000; % 50 kHz max
        dopplerAlpha = min(abs(dopplerShift) / maxDoppler, 1.0);

        % Pulsing effect for data transmission (0.5 to 1.0)
        pulsePhase = mod(frameCount / 10, 1); % Complete pulse every 10 frames
        pulseIntensity = 0.5 + 0.5 * sin(pulsePhase * 2 * pi);

        %% Update 3D View
        % Update satellite position
        set(satMarker, 'XData', satPos(1), 'YData', satPos(2), 'ZData', satPos(3));

        % Update beams
        % Central source to satellite (pattern distribution)
        set(beamCentralToSat, 'XData', [centralSourcePos(1), satPos(1)], ...
                              'YData', [centralSourcePos(2), satPos(2)], ...
                              'ZData', [centralSourcePos(3), satPos(3)], ...
                              'Color', [0, 1, 1, 0.4]);

        % Central source to ground station (pattern distribution)
        set(beamCentralToGS, 'XData', [centralSourcePos(1), gsRadius], ...
                             'YData', [centralSourcePos(2), 0], ...
                             'ZData', [centralSourcePos(3), 0], ...
                             'Color', [1, 0, 1, 0.4]);

        % Satellite to ground station (data transmission)
        if visible
            % Alpha based on Doppler effect AND pulsing
            beamAlpha = (0.3 + 0.6*dopplerAlpha) * pulseIntensity;
            beamColor = [1, 1, 0, beamAlpha]; % Yellow with dynamic alpha
            set(beamSatToGS, 'XData', [satPos(1), gsRadius], ...
                             'YData', [satPos(2), 0], ...
                             'ZData', [satPos(3), 0], ...
                             'Color', beamColor, 'LineWidth', 3 + 2*pulseIntensity);

            % Animate data flow markers along the beam
            % Position markers at different phases along the beam path
            t1 = mod(pulsePhase, 1);
            t2 = mod(pulsePhase + 0.33, 1);
            t3 = mod(pulsePhase + 0.66, 1);

            % Interpolate positions along beam (satellite -> ground station)
            marker1Pos = satPos * (1-t1) + [gsRadius; 0; 0] * t1;
            marker2Pos = satPos * (1-t2) + [gsRadius; 0; 0] * t2;
            marker3Pos = satPos * (1-t3) + [gsRadius; 0; 0] * t3;

            set(dataFlowMarker1, 'XData', marker1Pos(1), 'YData', marker1Pos(2), 'ZData', marker1Pos(3));
            set(dataFlowMarker2, 'XData', marker2Pos(1), 'YData', marker2Pos(2), 'ZData', marker2Pos(3));
            set(dataFlowMarker3, 'XData', marker3Pos(1), 'YData', marker3Pos(2), 'ZData', marker3Pos(3));
        else
            % Invisible beam and markers when not visible
            set(beamSatToGS, 'XData', [], 'YData', [], 'ZData', []);
            set(dataFlowMarker1, 'XData', [], 'YData', [], 'ZData', []);
            set(dataFlowMarker2, 'XData', [], 'YData', [], 'ZData', []);
            set(dataFlowMarker3, 'XData', [], 'YData', [], 'ZData', []);
        end

        %% Update Info Panel
        set(txtTime, 'String', sprintf('Time: %.1f s', currentTime));
        set(txtRange, 'String', sprintf('Range: %.2f km', range));

        % Range rate with direction indicator
        if rangeRate > 0
            direction = '→ Approaching';
        else
            direction = '← Receding';
        end
        set(txtRangeRate, 'String', sprintf('Range Rate: %.3f km/s %s', abs(rangeRate), direction));

        set(txtElevation, 'String', sprintf('Elevation: %.2f°', elevation));
        set(txtTxFreq, 'String', sprintf('Tx Freq: %.6f MHz', txFreq/1e6));
        set(txtDoppler, 'String', sprintf('Doppler Shift: %+.3f kHz (%.1f%% α)', ...
                                          dopplerShift/1e3, dopplerAlpha*100));
        set(txtRxFreq, 'String', sprintf('Rx Freq (Doppler): %.6f MHz', rxFreq/1e6));
        set(txtCompFreq, 'String', sprintf('Compensated Freq: %.6f MHz', compFreq/1e6));

        % Check for visibility transitions
        persistent wasVisible;
        if isempty(wasVisible)
            wasVisible = false;
        end

        if visible
            if ~wasVisible
                % Just entered visibility window!
                fprintf('[ENTER] Satellite entered visibility window at t=%.1fs, elevation=%.1f°\n', ...
                        currentTime, elevation);
                wasVisible = true;
            end
            if success
                set(txtSuccess, 'String', '⬤ TRANSMITTING - DECODED', 'Color', 'g');
            else
                set(txtSuccess, 'String', '⬤ TRANSMITTING - SYNC ERROR', 'Color', 'r');
            end
        else
            if wasVisible
                % Just exited visibility window!
                fprintf('[EXIT] Satellite exited visibility window at t=%.1fs\n', currentTime);
                wasVisible = false;
            end
            set(txtSuccess, 'String', '○ NOT VISIBLE', 'Color', [0.5, 0.5, 0.5]);
        end

        % Buffer status (simplified)
        bufferLevel = mod(i, 50);
        set(txtBuffer, 'String', sprintf('Buffer: %d/50 patterns', 50-bufferLevel));

        %% Update Frequency Chart
        % Only add to plot when actually transmitting (visible)
        if visible && ~isnan(txFreq)
            timeHistory(end+1) = currentTime;
            freqHistory(end+1) = txFreq/1e6;
        end

        % Update plot if we have data
        if ~isempty(timeHistory)
            % Keep only last 50 seconds of data
            windowSize = min(500, length(timeHistory));
            plotTimes = timeHistory(end-windowSize+1:end);
            plotFreqs = freqHistory(end-windowSize+1:end);

            % Update plot with relative time (starting from 0)
            if length(plotTimes) > 1
                set(freqPlot, 'XData', plotTimes - plotTimes(1), 'YData', plotFreqs);
                xlim(axFreq, [0, max(50, plotTimes(end) - plotTimes(1))]);
            end
        end

        %% Update and Pause
        drawnow limitrate;

        % Advance frame
        i = i + animData.frameSkip;

        % Pause based on speed (simulate time passing)
        pause(0.001 / animData.speedMultiplier);
    else
        % Paused - just wait
        pause(0.1);
    end
end

%% Cleanup
if ishandle(fig)
    fprintf('\nAnimation complete!\n');
    fprintf('Figure will remain open. Close window to exit.\n');
end

%% Keyboard Callback Function
function keyPressCallback(src, event, txtStatus, txtSpeed)
    animData = get(src, 'UserData');

    switch event.Key
        case 'space'
            animData.paused = ~animData.paused;
            if animData.paused
                set(txtStatus, 'String', 'PAUSED', 'Color', 'y');
            else
                set(txtStatus, 'String', 'RUNNING', 'Color', 'g');
            end

        case 'uparrow'
            animData.speedMultiplier = min(animData.speedMultiplier * 2, 1000);
            set(txtSpeed, 'String', sprintf('Speed: %dx', animData.speedMultiplier));

        case 'downarrow'
            animData.speedMultiplier = max(animData.speedMultiplier / 2, 1);
            set(txtSpeed, 'String', sprintf('Speed: %dx', animData.speedMultiplier));

        case 'q'
            animData.quit = true;
            fprintf('Quit requested...\n');
            if ishandle(src)
                close(src);
            end
    end

    % Save updated animData back to figure
    set(src, 'UserData', animData);
end
