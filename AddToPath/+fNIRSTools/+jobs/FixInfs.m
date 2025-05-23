classdef FixInfs < nirs.modules.AbstractModule
%% FixInfs - Attempts to fix Inf values by interpolation.
%
% Options:
%    ifFailReplaceWith - value to replace inf with if interpolation fails
%
% Notes:
%     1 is a good value for raw data; 0 otherwise

    properties
        ifFailReplaceWith = 1; % value to replace inf with if interpolation fails
        type='linear';
    end
    
    methods

        function obj = FixInfs( prevJob )
           obj.name = 'Fix Infs';
           
           if nargin > 0
               obj.prevJob = prevJob;
           end
        end
        
        function data = runThis( obj, data )
            for i = 1:numel(data)

                d = data(i).data;
                t = data(i).time;
                
                lst = isinf(d);
                
                if any(lst(:))
                    try
                        for j = 1:size(d,2)
                            if(all(lst(:,j)))
                                 d(lst(:,j),j) = obj.ifFailReplaceWith;
                            elseif any(lst(:,j))
                                % interpolation
                                l = lst(:,j);
                                d(l,j) = interp1(t(~l), d(~l,j), t(l),obj.type);
                                data(i).data = d;
                            end
                        end
                        
                    catch
                        % just replace with white noise
                        d(lst) = obj.ifFailReplaceWith;
                    end

                end
                
                % repeat to get the edges using nearest
                lst = isinf(d);
                
                if any(lst(:))
                    try
                        for j = 1:size(d,2)
                            if(all(lst(:,j)))
                                 d(lst(:,j),j) = obj.ifFailReplaceWith;
                            elseif any(lst(:,j))
                                % interpolation
                                l = lst(:,j);
                                d(l,j) = interp1(t(~l), d(~l,j), t(l),'nearest','extrap');
                                data(i).data = d;
                            end
                        end
                        
                    catch
                        % just replace with white noise
                        d(lst) = obj.ifFailReplaceWith;
                    end

                end
                

                data(i).data=d;
            end
        end
    end
    
end

