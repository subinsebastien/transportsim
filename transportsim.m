clc;
clearvars;

plot_col = 4;
plot_row = 3;

% Number of cities in Kerala
num_cities = 20;

% Populate each city with people
city_population = randi(10000, [1 num_cities]);
kerala_population = sum(city_population);

subplot(plot_row,plot_col,1);
x = 1:20;
y = randi(20, [1 20]);
cz = randi(100, [1 20]);
bubblechart(x,y,city_population, cz,'MarkerFaceAlpha',0.20);
bubblelegend('Scale','Location','eastoutside')
title("City Population");


% Imagine a maximum of 1% city population travels
travellers_perc = 0.01;

% Total number of hours a bus could run a day
total_time = 18;

% Three classes of bus.
%   - Ordinary running at 25km/hr
%   - Limited Stop running at 35km/hr
%   - Super Fast running at 50km/hr
% It is assumed that the longer the distance a given bus route has
% the faster the class the bus used belong to. For example, we don't
% use an Ordinary bus to run a 500km route.
avarage_bus_speeds = [25 35 50];

% Ticket price per kilometer travelled on each class of buses
fare_per_km = [1 1.5 2];

% Running expernse for each classes of buses per km
runing_exp_per_km = [50 55 60];

% Number of buses KSRTC has (5000 or so actual buses)
number_of_buses = 10;

% Initializing some arrays
total_distances = [];
route_list = {};
profit_growth = [];
population_coverage = [];

% Seat capacity
seat_capacity = 50;

% Number of optimzation runs
num_days = 7;
num_of_opt_runs = 30;

% Initialize a graph data structure
G = graph;

% Disconnected cities
dnodes = 1:num_cities;

% Build a complete road network
while ~(isempty(dnodes))
    s = randi([1,num_cities]);
    t = randi([1,num_cities]);
    while(s == t)
        t = randi([1,num_cities]);
    end
    % Lenght of the road in km (max distance between cities 50km)
    w = randi(50);

    % Add a road
    G = addedge(G, s, t, w);
    indices = ismember(dnodes, [s, t]);
    dnodes(indices) = [];
end

% Plot the original graph
subplot(plot_row,plot_col,2);
plot(G, '-*k');
title("Road Network");

% Create a number of bus routes
for rx = 1:number_of_buses

    % Create a new bus route
    bus_route = create_bus_route(G, num_cities);
    
    % Add bus route to the list
    route_list = {route_list{:}, bus_route};
    edges = findedge(G, bus_route(1:end-1), bus_route(2:end));
    
    % Create a subgraph
    H = subgraph(G, unique(bus_route));
    subplot(plot_row,plot_col,3);
    plot(H, '-*r', 'LineWidth', 2);
    title("Route Maps");
    drawnow

    % Distance array (distance of each bus routes)
    total_distances = [total_distances; calculateTotalWeight(G, bus_route)];
end

% disp(total_distances);
subplot(plot_row,plot_col,4);
bar(total_distances);
title("Total Distances");

% Allocate buses to all three classes based on route distances
% Longer routes get higher class bus.
quartiles = prctile(total_distances, [25 50 75]);

% Save original city population before simulation
orig_population = city_population;

% Route Optimization Repeats
for route_opts = 1:num_of_opt_runs

    % Re-assign the original population after each iteration
    % Assumption is that, after 7 days, every commuter will be back home
    city_population = orig_population;
    
    % Initialize Daily Profits array
    daily_profits = [];

    % Start Simulating for a number of days
    for daynames = 1:num_days
        total_expenses = [];
        profits = [];
    
        % Run each buses
        for ri = 1:length(route_list)
    
            bus_route = route_list{ri};
            d = total_distances(ri);
    
            % Find the bus class to use
            m = min(find(quartiles > d));
            
            % Use the highest class
            if isempty(m)
                m = 3;
            end
    
            % Calculate the number of trips
            speed = avarage_bus_speeds(m);
            max_distance = speed * total_time;
            num_trips = floor(max_distance / d);
    
            % Calculate the expense for the given bus
            exp = runing_exp_per_km(m);
            total_expense = num_trips * d * exp;
            fare = fare_per_km(m);
        
            % Initialize route variables
            collection = 0;   
            occupations = [];
    
            % Run each trips (Both back and forth)
            for kx = 1:num_trips
    
                % Find the direction of the route
                if ~mod(kx, 2)
                    bus_route = fliplr(bus_route);
                end
    
                % Set bus as empty
                occupation = 0;
    
                % Run the bus through all bus stops
                % -------------------------------------------------------------
                % NOTE : I'm considering each city as a bus stop. Ideally we
                % should simulate multiple bus stops between each cities. The
                % consideration was made to speed up the simulation.
                % -------------------------------------------------------------
    
                for sidx = 1:length(bus_route)
    
                    % City Index
                    cidx = bus_route(sidx);
    
                    % Find travellers
                    boarding = 0;
                    deboarding = 0;
    
                    % A random out of those today's travellers will board this
                    % bus in this trip
                    commuters = floor(city_population(cidx) * travellers_perc);
                    if commuters > 0
                        boarding = randi(commuters);
                    end
                    
                    % Deboard some people if there are occupants
                    if occupation > 0
                        deboarding = randi(occupation);
                    end
    
                    % Prevent overloading the bus. If too many people are
                    % there only board people until bus is full
                    if boarding > (seat_capacity - occupation)
                        boarding = (seat_capacity - occupation);
                    end
    
                    % Update availability
                    %disp("city = " + cidx + "        " + (occupation + boarding - deboarding) + " = " + occupation + " + " + boarding + " - " + deboarding);
                    occupation = occupation + boarding - deboarding;
    
                    % Update city populations
                    city_population(cidx) = city_population(cidx) + deboarding;
                    city_population(cidx) = city_population(cidx) - boarding;
    
                    % Occupations for all stops
                    occupations = [occupations occupation];
    
                    % If we reached last stop
                    if sidx == length(bus_route)
                        % Drop everyone at the last stop
                        city_population(cidx) = city_population(cidx) + occupation;
                    else
                        % Update collection
                        travel_distance = min(G.Edges.Weight(findedge(G, bus_route(sidx), bus_route(sidx + 1))));
                        fare_multiplied = travel_distance * fare * occupation;
                        collection = collection + fare_multiplied;
                    end
    
                end
                %disp(city_population(:));
            end
    
            subplot(plot_row,plot_col,5);
            bar(occupations);
            title("Seat Occupations");
        
            % Calculate profit for the day for this bus
            profit = collection - total_expense;
            profits = [profits profit];
        
            % Add for graphics
            total_expenses = [total_expenses total_expense];
        end
    
        subplot(plot_row,plot_col,6);
        bar(total_expenses);
        title("Expenses to Run");
        
        subplot(plot_row,plot_col,7);
        bar(profits);
        title("Trip Profits");
        drawnow
    
        daily_profits = [daily_profits; profits];
    end
    
    subplot(plot_row,plot_col,8);
    bar(sum(daily_profits, 2));
    title("KSRTC Daily Profits (7 Days)");
    
    result = sum(sum(daily_profits));
    profit_growth = [profit_growth result];

    disp("Total Result = " + result);
    
    route_profits = sum(daily_profits, 1);
    subplot(plot_row,plot_col,9);
    bar(route_profits);
    title("Profits in Each Route");
    
    % If there are losses, offset all profits by that
    stds = std(daily_profits);
    subplot(plot_row,plot_col,10);
    bar(stds);
    title("Standard Dev");
    
    % Print max profitable route
    [val, idmax] = max(route_profits);
    route_list(idmax);
    
    % Route Optimization
    [val, idmin] = min(route_profits);

    disp("Least Profitable Bus# (" + idmin + ") => " + num2str(cell2mat(route_list(idmin))));

    subplot(plot_row,plot_col,11);
    plot(profit_growth, '-*');
    title("Profit Growith");

    % Create a brand new bus route if in loss
    new_bus_route = create_bus_route(G, num_cities);
    route_list(idmin) = {new_bus_route};
    disp("Replacement route         => " + num2str(new_bus_route));
    
    disp(route_list(:));
end

% Calculate the population coverage of each bus
for spx = 1:number_of_buses
    abcd = cell2mat(route_list(spx));
    pop_sum = sum(city_population(abcd));
    population_coverage = [population_coverage pop_sum];
end
subplot(plot_row,plot_col,12);
bar(population_coverage);
title("Population Coverage");


% Calculate the total weights on each subgraph (route)
function totalWeight = calculateTotalWeight(G, T)
    totalWeight = 0;
    for i = 1:length(T)-1
        edgeWeight = min(G.Edges.Weight(findedge(G, T(i), T(i+1))));
        totalWeight = totalWeight + edgeWeight;
    end
end

% Create a route that connects a few cities
function bus_route = create_bus_route(G, num_cities)
    start_city = randi([1,num_cities]);
    components = conncomp(G);
    cluster = components(start_city);
    num_cities = sum(components == cluster);
    cities_to_connect = randi([2,num_cities]);
    bus_route = start_city;
    visited = start_city;
    
    % Decide which neighbouring cities to connect
    for k = 1:cities_to_connect-1
        next_node = setdiff(neighbors(G, bus_route(end)),visited);

        % Might have reached a leaf city
        if ~isempty(next_node)
            next_node = next_node(randi([1,length(next_node)]));
            bus_route = [bus_route, next_node];
            visited = [visited, next_node];
        end
        
    end
end