classdef ClockModel < handle
    % ClockModel - Models clock drift for satellite and ground station
    % Based on academic literature: quadratic drift model (bias, drift, aging)

    properties
        bias            % Initial clock offset (seconds)
        drift           % Clock drift rate (seconds/second) - typically 1e-9 to 1e-11
        aging           % Clock aging (seconds/second^2) - typically 1e-13 to 1e-15
        startTime       % Reference time (seconds)
        clockType       % 'satellite' or 'ground'
    end

    methods
        function obj = ClockModel(clockType)
            % Constructor - Initialize clock with realistic parameters
            obj.clockType = clockType;
            obj.startTime = 0;

            if strcmp(clockType, 'satellite')
                % Satellite clocks are typically high-quality rubidium or cesium
                % Stability: ~1e-11 to 1e-12 (short term)
                obj.bias = randn() * 1e-6;      % Initial offset: ~1 microsecond RMS
                obj.drift = randn() * 1e-11;    % Drift rate: ~10 ps/s
                obj.aging = randn() * 1e-14;    % Aging: ~0.01 ps/s^2
            else
                % Ground station clocks can be GPS-disciplined or rubidium
                % Slightly better than satellite due to less harsh environment
                obj.bias = randn() * 5e-7;      % Initial offset: ~0.5 microsecond RMS
                obj.drift = randn() * 5e-12;    % Drift rate: ~5 ps/s
                obj.aging = randn() * 5e-15;    % Aging: ~0.005 ps/s^2
            end
        end

        function error = getClockError(obj, t)
            % Calculate clock error at time t using quadratic model
            % error(t) = bias + drift*(t-t0) + 0.5*aging*(t-t0)^2
            dt = t - obj.startTime;
            error = obj.bias + obj.drift * dt + 0.5 * obj.aging * dt^2;
        end

        function drift = getDriftRate(obj, t)
            % Get instantaneous drift rate at time t
            % drift_rate(t) = drift + aging*(t-t0)
            dt = t - obj.startTime;
            drift = obj.drift + obj.aging * dt;
        end

        function reset(obj, t)
            % Reset reference time (e.g., after synchronization update)
            obj.startTime = t;
            % Bias becomes current error
            obj.bias = obj.getClockError(t);
        end

        function sync(obj, t, correction)
            % Apply synchronization correction (e.g., from GPS update)
            % Reduces bias but doesn't eliminate drift/aging
            obj.bias = obj.bias - correction;
            obj.startTime = t;
        end
    end
end
