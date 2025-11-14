classdef LinkBudgetModel < handle
    % LinkBudgetModel - Calculates SNR for satellite-ground link
    % Includes: path loss, atmospheric effects, system parameters

    properties
        frequency       % Carrier frequency (Hz)
        txPower         % Transmit power (dBW)
        txGain          % Transmit antenna gain (dBi)
        rxGain          % Receive antenna gain (dBi)
        systemTemp      % System noise temperature (K)
        bandwidth       % Signal bandwidth (Hz)
        c               % Speed of light (m/s)
    end

    methods
        function obj = LinkBudgetModel(frequency, txPower, txGain, rxGain, systemTemp, bandwidth)
            % Constructor
            obj.frequency = frequency;
            obj.txPower = txPower;          % e.g., 10 dBW = 10W
            obj.txGain = txGain;            % e.g., 15 dBi for satellite
            obj.rxGain = rxGain;            % e.g., 20 dBi for ground station
            obj.systemTemp = systemTemp;    % e.g., 300K for ground receiver
            obj.bandwidth = bandwidth;      % e.g., 1 MHz for FHSS channel
            obj.c = 299792458;              % Speed of light (m/s)
        end

        function [snr_dB, components] = calculateSNR(obj, range, elevation)
            % Calculate received SNR including all impairments
            % range: distance in km
            % elevation: elevation angle in degrees

            % Free space path loss (FSPL)
            range_m = range * 1000;
            lambda = obj.c / obj.frequency;
            fspl_dB = 20*log10(4*pi*range_m/lambda);

            % Atmospheric attenuation (frequency and elevation dependent)
            atm_dB = obj.getAtmosphericLoss(elevation);

            % Ionospheric effects (mainly for L/S-band)
            iono_dB = obj.getIonosphericLoss(elevation);

            % Rain fade (probabilistic, elevation dependent)
            rain_dB = obj.getRainFade(elevation);

            % EIRP (Effective Isotropic Radiated Power)
            eirp_dBW = obj.txPower + obj.txGain;

            % Received power
            rxPower_dBW = eirp_dBW - fspl_dB - atm_dB - iono_dB - rain_dB + obj.rxGain;

            % Noise power
            % N = k * T * B, where k = Boltzmann constant
            k_dBW_K_Hz = -228.6; % Boltzmann constant in dBW/K/Hz
            noisePower_dBW = k_dBW_K_Hz + 10*log10(obj.systemTemp) + 10*log10(obj.bandwidth);

            % SNR
            snr_dB = rxPower_dBW - noisePower_dBW;

            % Store components for debugging/analysis
            components = struct();
            components.fspl_dB = fspl_dB;
            components.atm_dB = atm_dB;
            components.iono_dB = iono_dB;
            components.rain_dB = rain_dB;
            components.eirp_dBW = eirp_dBW;
            components.rxPower_dBW = rxPower_dBW;
            components.noisePower_dBW = noisePower_dBW;
            components.snr_dB = snr_dB;
        end

        function loss_dB = getAtmosphericLoss(obj, elevation)
            % Tropospheric attenuation (oxygen, water vapor)
            % Strongly elevation-dependent (more atmosphere at low elevations)
            % At 2 GHz (S-band): ~0.1-0.5 dB zenith

            % Zenith attenuation at 2 GHz
            zenith_atten = 0.2; % dB

            % Elevation-dependent path length factor
            % Simple cosecant model for low elevations
            if elevation < 10
                % High attenuation at low elevations
                path_factor = 1 / sind(max(elevation, 5));
            else
                path_factor = 1 / sind(elevation);
            end

            loss_dB = zenith_atten * path_factor;

            % Add margin for clouds/fog (probabilistic)
            if rand() < 0.1 % 10% chance of clouds
                loss_dB = loss_dB + rand() * 2; % 0-2 dB additional loss
            end
        end

        function loss_dB = getIonosphericLoss(obj, elevation)
            % Ionospheric scintillation and absorption
            % More severe at low elevations
            % Frequency dependent: loss ~ 1/f^2

            % Reference loss at 1 GHz, zenith
            loss_1GHz = 0.5; % dB

            % Scale by frequency (inversely proportional to f^2)
            freq_GHz = obj.frequency / 1e9;
            loss_zenith = loss_1GHz / (freq_GHz^2);

            % Elevation dependency (worse at low elevations)
            if elevation < 20
                elev_factor = 1 + (20 - elevation) / 10;
            else
                elev_factor = 1;
            end

            loss_dB = loss_zenith * elev_factor;

            % Add scintillation (random fading)
            scintillation = randn() * 0.3; % ~0.3 dB RMS
            loss_dB = loss_dB + abs(scintillation);
        end

        function loss_dB = getRainFade(obj, elevation)
            % Rain attenuation (highly variable)
            % At 2 GHz: ~0.01 dB/km for light rain, ~0.1 dB/km for heavy rain

            % Probability of rain (10% chance)
            if rand() < 0.1
                % Rain present - calculate path through rain
                rain_height = 3; % km (typical rain height)

                % Path length through rain
                if elevation < 90
                    path_length = rain_height / sind(max(elevation, 5));
                else
                    path_length = rain_height;
                end

                % Rain rate (random: light to moderate)
                rain_rate_mm_hr = rand() * 10; % 0-10 mm/hr

                % Specific attenuation at 2 GHz (ITU-R model approximation)
                % gamma = k * R^alpha, where R is rain rate
                k = 0.0001; % frequency dependent
                alpha = 1.0;
                specific_atten = k * (rain_rate_mm_hr ^ alpha); % dB/km

                loss_dB = specific_atten * path_length;
            else
                loss_dB = 0; % No rain
            end
        end
    end
end
