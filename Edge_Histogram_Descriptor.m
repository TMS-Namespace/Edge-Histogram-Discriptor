classdef Edge_Histogram_Descriptor < handle
    % Implementation of MPEG-7 texture descriptor "Edge Histogram Descriptor", in addition to
    % the suggested improvements for semi-local features according to the
    % "Efficient Use of Local Edge Histogram Descriptor" paper by Dong Kwon
    % Park, Yoon Seok Jeon, Chee Sun Won
    
    % Definitions: since different papers names the below differently, this
    % is a small clarification: image is divided into blocks (typically 4x4 blocks, however, 
    % this class allows to define other values), each block is divided into cells of size
    % 2x2 pixels, and the blocks are furthermore, combined into clusters, to "average" over
    % them, and extract semi-global features.
    
    % Created by: TMS-Namespace
    % Publishing date: 27/11/2021
    % Ref: https://github.com/TMS-Namespace
    
    properties % public properties
        
        % a flag if bins should be normalized (by cells count, or block count in clusters)
        normalize
        % threshold for considering cells vote as considerable
        threshold
        
        % the number of vertical and horizontal blocks that the image will
        % be divided into
        horizontal_blocks_count
        vertical_blocks_count

    end
    
    properties (Access = private)
        
        % will handle our image
        image
        
       % will handle block bins, indexed by block index
        indexed_blocks_bins = [];
        
        % will handle information on block sizes in pixels
        horizontal_block_size
        vertical_block_size
        
        % will handle matrix operators
        matrix_operator_vertical
        matrix_operator_horizontal
        matrix_operator_right_to_left_diagonal
        matrix_operator_left_to_right_diagonal
        matrix_operator_nondirectional
        
    end
    
    methods  (Access = private)
        
        function calc_indexed_blocks_bins(obj)
            % divides the image into blocks, and calculates the bins for
            % each block. It will store the results in internal property,
            % as block coordinate index, plus the block bins, so we can iterate and use
            % them letter on for clustering. Note that those blocks are
            % not normalized.
            
            % this is main method that should be called internally, before any further
            % calculations, so this is a good place to check if we have
            % correct inputs:
            [c, r] = size(obj.image);
            
            % block sizes should be multiple of 4 for clustering to work
             if mod(obj.horizontal_blocks_count, 4) ~= 0 || mod(obj.vertical_blocks_count, 4) ~= 0
                ME = MException('Edge_Histogram_Descriptor:Bad_Input', 'EHD requires Block_Size to be multiple of 4.');
                throw(ME);
            end
            % image size should be multiple of 2, to be able to generate
            % 2x2 cell, also it should be multiple of block_size, to be
            % able to divide it into blocks
            if mod(c, 2 * obj.horizontal_blocks_count) ~= 0 || mod(r, 2 * obj.vertical_blocks_count) ~= 0
                ME = MException('Edge_Histogram_Descriptor:Bad_Input', 'EHD requires image size to be multiple of 2*Block_Size.');
                throw(ME);
            end

            obj.horizontal_block_size = c / obj.horizontal_blocks_count;
            obj.vertical_block_size =  r / obj.vertical_blocks_count;

            % split image to blocks
            for y = 0 : obj.vertical_blocks_count - 1 % we start from zero
                for x = 0 : obj.horizontal_blocks_count - 1
                    % generate the block
                    block = obj.image(y * obj.vertical_block_size + 1 : (y + 1) * obj.vertical_block_size, x * obj.horizontal_block_size +1: (x + 1) * obj.horizontal_block_size);
                    % generate block bins and store them
                    obj.indexed_blocks_bins (y + 1, x + 1, :) = obj.get_block_bins(block);
                end
            end
            
        end
        
        function block_bins = get_block_bins(obj, block)
            % divides the blocks into cells, and calcs the bins for this block, and returns a 
            % vector of 5 bins
            [c, r] = size(block);

            cells_per_block_horizontal = c / 2;
            cells_per_block_vertical =  r / 2;

            block_bins = zeros(1, 5);

            for y = 0 : cells_per_block_vertical - 1 % we start from zero
                for x = 0 : cells_per_block_horizontal - 1
                    % generate 2x2 cell
                    cell = block(2 * y + 1 : 2 * y + 2, 2 * x + 1: 2 * x + 2);
                    % get most representative bin
                    bin_index = obj.get_cell_bin_index(cell);
                    % if a valid bin is found, increase the corresponding bin
                    % value
                    if bin_index > 0
                        block_bins(bin_index) = block_bins(bin_index) + 1;
                    end
                end
            end
            
        end
        
        function bin_index = get_cell_bin_index(obj, cell)
            % the core of EHD method, applies matrix operators on cells,
            % and returns the dominant/best representative bin index
            cell = double(cell);
            votes = zeros(5);
            
            % calc votes for each possible edge class
            votes(1) = obj.conv(cell, obj.matrix_operator_vertical);
            votes(2) = obj.conv(cell, obj.matrix_operator_horizontal);
            votes(3) = obj.conv(cell, obj.matrix_operator_right_to_left_diagonal);
            votes(4) = obj.conv(cell, obj.matrix_operator_left_to_right_diagonal);
            votes(5) = obj.conv(cell, obj.matrix_operator_nondirectional);
            
            % find the maximum vote
            [vote, bin_index] = max(votes, [], 'all','linear');
            
            % if the max vote smaller than a threshold, we return 0, that
            % corresponds to no bin
            if vote < obj.threshold
                bin_index = 0 ;
            end
            
        end

        function res = conv(obj, a, b)
            % a help function to perform convolution on matrix operators
            % and cells
            res = abs(conv2(a, b, 'valid'));
        end

        function bins_vectors = sum_block_bins(obj, from_x, to_x, from_y, to_y)
            % this is just a help function, to sum block bins within a
            % particular range, and normalize the sum by cell and block count, 
            % this will useful in multiple places
            
            bins_vectors = zeros(1, 5);
            
            for x = from_x : to_x
                for y = from_y : to_y
                    % sum bins of blocks
                    bins_vectors = bins_vectors +  reshape(obj.indexed_blocks_bins(y, x, :), [1, 5]);
                end
            end
            
            % normalize by cells count, and block count
            if obj.normalize
                cells_per_block = (obj.horizontal_block_size / 2) * (obj.horizontal_block_size / 2);
                blocks_count = (to_x - from_x + 1) * (to_y - from_y + 1);
                bins_vectors = bins_vectors / (cells_per_block * blocks_count);
            end
            
        end 
        
    end
    
    methods % public methods

       function obj = Edge_Histogram_Descriptor(image)
            
           % the image should be mono channel gray image
           if ndims(image) > 2
                ME = MException('Edge_Histogram_Descriptor:Bad_Input', 'EHD requires mono-channel (gray) images.');
                throw(ME);
            end
           
            obj.image = image;
            
            obj.normalize = false;
            obj.threshold = 50;
            
            obj.horizontal_blocks_count = 4;
            obj.vertical_blocks_count = 4;
            
            % edge orientation matrix operators
            obj.matrix_operator_vertical = [1 -1; 1 -1];
            obj.matrix_operator_horizontal = [1 1; -1 -1];
            obj.matrix_operator_right_to_left_diagonal= [1.414 0; 0 -1.414];
            obj.matrix_operator_left_to_right_diagonal = [0 1.414; -1.414 0];
            obj.matrix_operator_nondirectional = [2 -2; -2 2];
            
        end

       function blocks_bins_vector = get_blocks_bins_vector(obj)
           % returns a vector of all block bins
           if isempty(obj.indexed_blocks_bins)
               obj.calc_indexed_blocks_bins();
           end    
           
           blocks_bins_vector = [];
           
            for y = 0 : obj.vertical_blocks_count - 1
                for x = 0 : obj.horizontal_blocks_count - 1               
                    blocks_bins_vector =  cat(2, blocks_bins_vector,  reshape(obj.indexed_blocks_bins(y + 1, x + 1, :), [1, 5]));
                end
            end           
            
            % normalize by number of cells
            if obj.normalize
                blocks_bins_vector = blocks_bins_vector / (obj.horizontal_block_size / 2 * obj.horizontal_block_size / 2);
            end
            
       end

       function global_bins_vector = get_global_bins_vector(obj)
           % returns a vector of 5 bins, that represents the sum of all
           % bins
           if isempty(obj.indexed_blocks_bins)
               obj.calc_indexed_blocks_bins();
           end    
           
           global_bins_vector = obj.sum_block_bins(1, obj.horizontal_blocks_count, 1, obj.vertical_blocks_count);
                   
        end
       
       function semi_local_bins_vector = get_semi_local_bins_vector(obj)
           % returns a vector of semi-local bins, i.e. bins of the clusters
           % of blocks.
           if isempty(obj.indexed_blocks_bins)
               obj.calc_indexed_blocks_bins();
           end    
           
           semi_local_bins_vector = [];
           cluster_bins_vector = zeros(1, 5);
           
           % generate horizontal clusters
            for y = 1 : obj.vertical_blocks_count
                for x = 1 : obj.horizontal_blocks_count
                    % sum bins of horizontal blocks
                    cluster_bins_vector = cluster_bins_vector +  reshape(obj.indexed_blocks_bins(y, x, :), [1, 5]);
                end
                % normalize by cells, and clusters' block count
                if obj.normalize
                    cells_per_block = (obj.horizontal_block_size / 2) * (obj.horizontal_block_size / 2);
                    blocks_count = obj.horizontal_blocks_count;
                    cluster_bins_vector = cluster_bins_vector / (cells_per_block * blocks_count);
                end
                % add this cluster to whole vector
                semi_local_bins_vector = cat(2, semi_local_bins_vector, cluster_bins_vector);
                % reset cluster vector for next cluster
                cluster_bins_vector = zeros(1, 5);
            end
            
            % generate vertical clusters
            for x = 1 : obj.horizontal_blocks_count
                for y = 1 : obj.vertical_blocks_count
                    % sum bins of blocks
                    cluster_bins_vector = cluster_bins_vector +  reshape(obj.indexed_blocks_bins(y, x, :), [1, 5]);
                end
                % normalize by cells, and clusters' block count
                if obj.normalize
                    cells_per_block = (obj.horizontal_block_size / 2) * (obj.horizontal_block_size / 2);
                    blocks_count = obj.vertical_blocks_count;
                    cluster_bins_vector = cluster_bins_vector / (cells_per_block * blocks_count);
                end
                % add this cluster to whole vector
                semi_local_bins_vector = cat(2, semi_local_bins_vector, cluster_bins_vector);
                % reset cluster vector for next cluster
                cluster_bins_vector = zeros(1, 5);
            end
            
            % generate upper-left cluster
            cluster_bins_vector = obj.sum_block_bins(1, obj.horizontal_blocks_count / 2, 1, obj.vertical_blocks_count / 2 );
            % add this cluster to whole vector
            semi_local_bins_vector = cat(2, semi_local_bins_vector, cluster_bins_vector);
                
            % generate upper-right cluster
            cluster_bins_vector = obj.sum_block_bins(obj.horizontal_blocks_count / 2 +1, obj.horizontal_blocks_count , 1, obj.vertical_blocks_count/2 );
            % add this cluster to whole vector
            semi_local_bins_vector = cat(2, semi_local_bins_vector, cluster_bins_vector);

            % generate bottom-left cluster
            cluster_bins_vector = obj.sum_block_bins(1, obj.horizontal_blocks_count / 2 , obj.vertical_blocks_count / 2 + 1, obj.vertical_blocks_count );
            % add this cluster to whole vector
            semi_local_bins_vector = cat(2, semi_local_bins_vector, cluster_bins_vector);
            
            % generate bottom-right cluster
            cluster_bins_vector = obj.sum_block_bins(obj.horizontal_blocks_count / 2 + 1, obj.horizontal_blocks_count, obj.vertical_blocks_count / 2 + 1, obj.vertical_blocks_count );
            % add this cluster to whole vector
            semi_local_bins_vector = cat(2, semi_local_bins_vector, cluster_bins_vector);
            
            % finally, generate the "middle" cluster
            cluster_bins_vector = obj.sum_block_bins(obj.horizontal_blocks_count / 4 + 1, obj.horizontal_blocks_count * 3 /4, obj.vertical_blocks_count / 4 + 1, obj.vertical_blocks_count * 3 / 4 );
            % add this cluster to whole vector
            semi_local_bins_vector = cat(2, semi_local_bins_vector, cluster_bins_vector);
            
       end
        
       function full_bins_vector = get_full_bins_vector(obj)
           % generates a combined vector of global, semi-local, and per block bins vector
           full_bins_vector = [];
           full_bins_vector = cat(2, full_bins_vector, obj.get_global_bins_vector());
           full_bins_vector = cat(2, full_bins_vector, obj.get_semi_local_bins_vector());
           full_bins_vector = cat(2, full_bins_vector, obj.get_blocks_bins_vector());
       end
       
    end
    
end

