function [v1, v2, cam_offsets, t, R ] = createMulti2D2DOmniExperiment( pt_per_cam, cam_number, noise, outlier_fraction )

%% generate the camera system

cam_distance = 1.0;

%% set a regular camera system with 2 or 4 cameras here
if cam_number == 2
  cam_offsets = [ cam_distance -cam_distance; 0.0 0.0; 0.0 0.0  ];
else
  cam_number = 4; % only two or 4 supported for this experiment
  cam_offsets = [ cam_distance 0.0 -cam_distance 0.0; 0.0 cam_distance 0.0 -cam_distance; 0.0 0.0 0.0 0.0 ];
end

%% generate random view-points

max_parallax = 2.0;
max_rotation = 0.5;

position1 = zeros(3,1);
rotation1 = eye(3);

position2 = max_parallax * 2.0 * (rand(3,1) - repmat(0.5,3,1));
rotation2 = generateBoundedR(max_rotation);

%% Generate random point-cloud

avg_depth_over_cam_distance = 10.0;
maxDepth = 5.0;

p = cell([cam_number 1]);

for cam=1:cam_number

  normalizedPoints = 2.0*(rand(3,pt_per_cam)-repmat(0.5,3,pt_per_cam));
  p{cam,1} = maxDepth * normalizedPoints;

end

%% Now create the correspondences by looping through the cameras

focal_length = 800.0;
v1 = cell([cam_number 1]);
v2 = cell([cam_number 1]);

for cam=1:cam_number

    v1{cam,1} = zeros(3,pt_per_cam);
    v2{cam,1} = zeros(3,pt_per_cam);

    for i=1:pt_per_cam
    
        cam_offset = cam_offsets(:,cam);
    
	    %special: shift the point in the first frame along current camera axis, which guarantees homogeneous distribution
	    temp = p{cam,1}(:,i) + avg_depth_over_cam_distance * cam_offset;
	    p{cam,1}(:,i) = temp;
	
        body_point1 = rotation1' * (p{cam,1}(:,i)-position1);
        body_point2 = rotation2' * (p{cam,1}(:,i)-position2);
    
        % we actually omit the can rotation here by unrotating the bearing
        % vectors already
        bearingVector1 = body_point1 - cam_offset;
        bearingVector2 = body_point2 - cam_offset;
        bearingVector1_norm = norm(bearingVector1);
        bearingVector2_norm = norm(bearingVector2);
        bearingVector1 = bearingVector1/bearingVector1_norm;
        bearingVector2 = bearingVector2/bearingVector2_norm;
    
        % add noise to the bearing vectors here
        bearingVector1_noisy = addNoise(bearingVector1,focal_length,noise);
        bearingVector2_noisy = addNoise(bearingVector2,focal_length,noise);
    
        % store the normalized bearing vectors along with the cameras they are
        % being seen (we create correspondences that always originate from the
        % same camera, you can change this if you want)
        bearingVector1_norm = norm(bearingVector1_noisy);
        bearingVector2_norm = norm(bearingVector2_noisy);
    
        v1{cam,1}(:,i) = [bearingVector1_noisy./bearingVector1_norm];
        v2{cam,1}(:,i) = [bearingVector2_noisy./bearingVector2_norm];
    end
end

%% Add outliers
outliers_per_cam = floor(outlier_fraction*pt_per_cam);

if outliers_per_cam > 0
for cam=1:cam_number

for i=1:outliers_per_cam
    
    cam_offset = cam_offsets(:,cam);
    
    %generate random point
    normalizedPoint = 2.0*(rand(3,1)-repmat(0.5,3,1));
    point = maxDepth * normalizedPoint + avg_depth_over_cam_distance * cam_offset;
	
    
    body_point2 = rotation2' * (point-position2);
    
    % store the point (no need to add noise)
    bearingVector2 = body_point2 - cam_offset;
    
    % store the normalized bearing vectors along with the cameras they are
    % being seen (we create correspondences that always originate from the
    % same camera, you can change this if you want)
    bearingVector2_norm = norm(bearingVector2);
    
    v2{cam,1}(:,i) = [bearingVector2./bearingVector2_norm];
end

end
end

%% compute relative translation and rotation

R = rotation1' * rotation2;
t = rotation1' * (position2 - position1);