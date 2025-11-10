classdef OrbitModel < handle
    % OrbitModel - Simple circular orbit model for satellite
    % Calculates position, velocity, and range to ground station

    properties
        altitude            % Orbital altitude in km
        inclination         % Orbital inclination in degrees
        orbitalPeriod       % Orbital period in seconds
        earthRadius         % Earth radius in km (6371 km)
        groundStationLat    % Ground station latitude in degrees
        groundStationLon    % Ground station longitude in degrees
        mu                  % Earth's gravitational parameter (km^3/s^2)
    end

    methods
        function obj = OrbitModel(altitude, inclination, groundStationLat, groundStationLon)
            % Constructor
            obj.altitude = altitude;
            obj.inclination = inclination;
            obj.groundStationLat = groundStationLat;
            obj.groundStationLon = groundStationLon;
            obj.earthRadius = 6371; % km
            obj.mu = 398600; % km^3/s^2 (Earth's gravitational parameter)

            % Calculate orbital period using Kepler's third law
            r = obj.earthRadius + obj.altitude;
            obj.orbitalPeriod = 2 * pi * sqrt(r^3 / obj.mu);
        end

        function [pos, vel] = getSatelliteState(obj, t)
            % Get satellite position and velocity at time t
            % Returns position in ECI (Earth-Centered Inertial) coordinates

            % Orbital angular velocity
            omega = 2 * pi / obj.orbitalPeriod;

            % Orbital radius
            r = obj.earthRadius + obj.altitude;

            % True anomaly (angle in orbit)
            theta = omega * t;

            % Position in orbital plane
            x_orb = r * cos(theta);
            y_orb = r * sin(theta);
            z_orb = 0;

            % Velocity in orbital plane
            v = sqrt(obj.mu / r); % Circular orbital velocity
            vx_orb = -v * sin(theta);
            vy_orb = v * cos(theta);
            vz_orb = 0;

            % Rotate by inclination
            inc_rad = deg2rad(obj.inclination);
            pos = [x_orb;
                   y_orb * cos(inc_rad);
                   y_orb * sin(inc_rad)];

            vel = [vx_orb;
                   vy_orb * cos(inc_rad);
                   vy_orb * sin(inc_rad)];
        end

        function [range, rangeRate] = getRangeToGroundStation(obj, t)
            % Calculate range and range rate to ground station
            % This is simplified - uses spherical approximation

            [satPos, satVel] = obj.getSatelliteState(t);

            % Ground station position (simplified - assumes equatorial plane)
            % In a full implementation, would rotate Earth based on time
            gs_lat_rad = deg2rad(obj.groundStationLat);
            gs_lon_rad = deg2rad(obj.groundStationLon);

            % Ground station position in ECI
            gsPos = [obj.earthRadius * cos(gs_lat_rad) * cos(gs_lon_rad);
                     obj.earthRadius * cos(gs_lat_rad) * sin(gs_lon_rad);
                     obj.earthRadius * sin(gs_lat_rad)];

            % Range vector
            rangeVec = satPos - gsPos;
            range = norm(rangeVec);

            % Range rate (relative velocity along line of sight)
            rangeRate = dot(satVel, rangeVec) / range;
        end

        function elevation = getElevationAngle(obj, t)
            % Get elevation angle from ground station to satellite
            [satPos, ~] = obj.getSatelliteState(t);

            gs_lat_rad = deg2rad(obj.groundStationLat);
            gs_lon_rad = deg2rad(obj.groundStationLon);

            gsPos = [obj.earthRadius * cos(gs_lat_rad) * cos(gs_lon_rad);
                     obj.earthRadius * cos(gs_lat_rad) * sin(gs_lon_rad);
                     obj.earthRadius * sin(gs_lat_rad)];

            rangeVec = satPos - gsPos;
            range = norm(rangeVec);

            % Simplified elevation calculation
            % Angle between range vector and local horizontal
            height = norm(satPos) - obj.earthRadius;
            elevation = rad2deg(asin(height / range));
        end

        function visible = isVisible(obj, t, minElevation)
            % Check if satellite is visible from ground station
            % minElevation in degrees (typically 5-10 degrees)
            elevation = obj.getElevationAngle(t);
            visible = elevation >= minElevation;
        end

        function orbitalVel = getOrbitalVelocity(obj)
            % Get circular orbital velocity
            r = obj.earthRadius + obj.altitude;
            orbitalVel = sqrt(obj.mu / r); % km/s
        end
    end
end
