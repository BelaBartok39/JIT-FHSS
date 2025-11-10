classdef DopplerModel < handle
    % DopplerModel - Models Doppler shift for satellite communications
    %
    % DOPPLER EFFECT EXPLANATION:
    % When a satellite moves relative to a ground station, the frequency
    % of the transmitted signal appears shifted due to relative motion.
    %
    % - If satellite is approaching: frequency increases (blue shift)
    % - If satellite is receding: frequency decreases (red shift)
    %
    % The Doppler shift is given by:
    %   f_received = f_transmitted * (1 + v_r/c)
    % where:
    %   v_r = radial velocity (range rate) - positive if approaching
    %   c = speed of light (3e8 m/s)
    %
    % For satellites at ~7-8 km/s orbital velocity, this can cause
    % frequency shifts of tens of kHz at GHz frequencies.
    %
    % IMPACT ON FHSS:
    % - Receiver must compensate for Doppler to correctly decode signal
    % - Doppler compensation requires knowing satellite position/velocity
    % - Pattern synchronization must account for propagation delay

    properties
        speedOfLight        % Speed of light in m/s
        enableCompensation  % Whether to apply Doppler compensation
    end

    methods
        function obj = DopplerModel()
            % Constructor
            obj.speedOfLight = 2.998e8; % m/s
            obj.enableCompensation = true;
        end

        function dopplerShift = calculateDopplerShift(obj, transmitFreq, rangeRate)
            % Calculate Doppler frequency shift
            % transmitFreq: transmitted frequency in Hz
            % rangeRate: range rate in km/s (positive = approaching)
            %
            % Returns: Doppler shift in Hz

            % Convert range rate to m/s
            rangeRate_ms = rangeRate * 1000;

            % Doppler shift formula
            % Positive range rate (approaching) -> positive shift (higher freq)
            dopplerShift = transmitFreq * (rangeRate_ms / obj.speedOfLight);
        end

        function receivedFreq = applyDopplerShift(obj, transmitFreq, rangeRate)
            % Apply Doppler shift to transmitted frequency
            % Returns the actual received frequency

            shift = obj.calculateDopplerShift(transmitFreq, rangeRate);
            receivedFreq = transmitFreq + shift;
        end

        function compensatedFreq = compensateDoppler(obj, receivedFreq, rangeRate, originalTransmitFreq)
            % Compensate for Doppler shift at receiver
            % Estimates original transmitted frequency

            if ~obj.enableCompensation
                compensatedFreq = receivedFreq;
                return;
            end

            % Calculate expected Doppler shift
            expectedShift = obj.calculateDopplerShift(originalTransmitFreq, rangeRate);

            % Remove Doppler shift
            compensatedFreq = receivedFreq - expectedShift;
        end

        function maxShift = getMaxDopplerShift(obj, frequency, maxVelocity)
            % Calculate maximum possible Doppler shift
            % frequency: carrier frequency in Hz
            % maxVelocity: maximum relative velocity in km/s

            maxVelocity_ms = maxVelocity * 1000;
            maxShift = frequency * (maxVelocity_ms / obj.speedOfLight);
        end

        function setCompensation(obj, enable)
            % Enable/disable Doppler compensation
            obj.enableCompensation = enable;
        end

        function delay = calculatePropagationDelay(obj, range)
            % Calculate one-way propagation delay
            % range: distance in km
            % Returns: delay in seconds

            range_m = range * 1000;
            delay = range_m / obj.speedOfLight;
        end

        function roundTripDelay = calculateRoundTripDelay(obj, range)
            % Calculate round-trip propagation delay
            % Important for pattern synchronization
            roundTripDelay = 2 * obj.calculatePropagationDelay(range);
        end
    end

    methods (Static)
        function plotDopplerProfile(timeVector, rangeRateVector, frequency)
            % Static method to plot Doppler shift over time
            doppler = DopplerModel();

            dopplerShifts = zeros(size(timeVector));
            for i = 1:length(timeVector)
                dopplerShifts(i) = doppler.calculateDopplerShift(frequency, rangeRateVector(i));
            end

            figure;
            subplot(2,1,1);
            plot(timeVector, rangeRateVector);
            xlabel('Time (s)');
            ylabel('Range Rate (km/s)');
            title('Satellite Range Rate vs Time');
            grid on;

            subplot(2,1,2);
            plot(timeVector, dopplerShifts / 1e3);
            xlabel('Time (s)');
            ylabel('Doppler Shift (kHz)');
            title(sprintf('Doppler Shift at %.2f MHz', frequency/1e6));
            grid on;
        end
    end
end
