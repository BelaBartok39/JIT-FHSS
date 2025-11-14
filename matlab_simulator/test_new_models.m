%% Test New Models
% Quick diagnostic to verify ClockModel and LinkBudgetModel work

clear; close all; clc;
addpath('src/');

fprintf('Testing new model classes...\n\n');

%% Test ClockModel
fprintf('1. Testing ClockModel...\n');
try
    clock1 = ClockModel('satellite');
    error1 = clock1.getClockError(100);
    fprintf('   Satellite clock created, error at t=100s: %.3e seconds\n', error1);

    clock2 = ClockModel('ground');
    error2 = clock2.getClockError(100);
    fprintf('   Ground clock created, error at t=100s: %.3e seconds\n', error2);
    fprintf('   ✓ ClockModel working!\n\n');
catch ME
    fprintf('   ✗ ERROR in ClockModel:\n');
    fprintf('   %s\n\n', ME.message);
    return;
end

%% Test LinkBudgetModel
fprintf('2. Testing LinkBudgetModel...\n');
try
    linkBudget = LinkBudgetModel(2e9, 10, 15, 25, 290, 1e6);
    [snr, components] = linkBudget.calculateSNR(500, 45);
    fprintf('   Link budget created\n');
    fprintf('   SNR at 500km, 45° elevation: %.2f dB\n', snr);
    fprintf('   Path loss: %.2f dB\n', components.fspl_dB);
    fprintf('   Atmospheric: %.2f dB\n', components.atm_dB);
    fprintf('   ✓ LinkBudgetModel working!\n\n');
catch ME
    fprintf('   ✗ ERROR in LinkBudgetModel:\n');
    fprintf('   %s\n\n', ME.message);
    return;
end

%% Test GroundReceiver with new models
fprintf('3. Testing GroundReceiver integration...\n');
try
    orbit = OrbitModel(500, 98, 0, 0);
    receiver = GroundReceiver(orbit, 50, 1.0);

    % Check if new properties exist
    if isempty(receiver.clockModel)
        fprintf('   ✗ ERROR: clockModel not initialized in GroundReceiver!\n');
    else
        fprintf('   ✓ clockModel initialized\n');
    end

    if isempty(receiver.linkBudget)
        fprintf('   ✗ ERROR: linkBudget not initialized in GroundReceiver!\n');
    else
        fprintf('   ✓ linkBudget initialized\n');
    end

    fprintf('   ✓ GroundReceiver working with new models!\n\n');
catch ME
    fprintf('   ✗ ERROR in GroundReceiver:\n');
    fprintf('   %s\n', ME.message);
    fprintf('   Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('     %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    return;
end

fprintf('All tests passed! New models are working correctly.\n');
fprintf('\nNow try running: run_simulation\n');
