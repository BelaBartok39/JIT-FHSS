%% Test Visibility - Debug Script
% Check what elevations we're actually getting

clear; close all; clc;
addpath('src/');

fprintf('=== Visibility Diagnostic ===\n\n');

% Current parameters
altitude = 500;
inclination = 45;
groundStationLat = 37.4;
groundStationLon = -122.1;

orbit = OrbitModel(altitude, inclination, groundStationLat, groundStationLon);

fprintf('Orbital Period: %.1f minutes\n', orbit.orbitalPeriod/60);
fprintf('Ground Station: %.1f°N, %.1f°W\n', groundStationLat, abs(groundStationLon));
fprintf('Orbit Inclination: %.1f°\n\n', inclination);

% Sample elevations over 2 orbits
fprintf('Sampling elevations over 2 orbital periods...\n');
timePoints = linspace(0, orbit.orbitalPeriod * 2, 1000);
elevations = zeros(size(timePoints));
ranges = zeros(size(timePoints));

for i = 1:length(timePoints)
    elevations(i) = orbit.getElevationAngle(timePoints(i));
    [ranges(i), ~] = orbit.getRangeToGroundStation(timePoints(i));
end

fprintf('  Max elevation: %.2f degrees\n', max(elevations));
fprintf('  Min elevation: %.2f degrees\n', min(elevations));
fprintf('  Min range: %.1f km\n', min(ranges));
fprintf('  Max range: %.1f km\n\n', max(ranges));

if max(elevations) < 5
    fprintf('PROBLEM: Satellite never gets above 5° elevation!\n');
    fprintf('Solution: Need to adjust orbital parameters or ground station.\n\n');

    fprintf('Suggested fixes:\n');
    fprintf('1. Use polar orbit: inclination = 90 degrees\n');
    fprintf('2. Use ground station on equator: groundStationLat = 0\n');
    fprintf('3. Use higher inclination: inclination = 60 degrees\n');
else
    fprintf('Good! Satellite reaches %.2f° elevation\n', max(elevations));
    % Find first time above 5°
    idx = find(elevations >= 5, 1, 'first');
    if ~isempty(idx)
        fprintf('First visibility at t = %.1f seconds\n', timePoints(idx));
    end
end

% Plot
figure('Position', [100, 100, 1000, 600]);

subplot(2,1,1);
plot(timePoints/60, elevations, 'b-', 'LineWidth', 1.5);
hold on;
yline(5, 'r--', 'LineWidth', 2, 'Label', '5° Minimum');
yline(0, 'k--', 'LineWidth', 1);
hold off;
xlabel('Time (minutes)');
ylabel('Elevation Angle (degrees)');
title('Satellite Elevation Angle vs Time');
grid on;
ylim([min(elevations)-5, max(elevations)+5]);

subplot(2,1,2);
plot(timePoints/60, ranges, 'g-', 'LineWidth', 1.5);
xlabel('Time (minutes)');
ylabel('Range (km)');
title('Satellite Range to Ground Station');
grid on;

fprintf('\nPlots generated. Check the figure window.\n');
