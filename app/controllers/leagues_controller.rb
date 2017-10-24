class LeaguesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_league, except: [:new, :create, :index]
    before_action :set_games, except: [:new, :create, :index]

    def index
        @leagues = League.all.order('name DESC')
    end

    def new
        if !current_user.admin
            redirect_to root_path
            flash[:alert] = "You do not have permission to enter that page."
        end
        @league = League.new
    end

    def create
        if !current_user.admin
            redirect_to root_path
            flash[:alert] = "You do not have permission to enter that page."
        end
        @league = League.new(league_params)

        if @league.save
            flash[:success] = "Your league has been created!"
            redirect_to @league
        else
            flash[:error] = "Your league couldn't be created. Please check the form."
            render :new
        end
    end

    def edit
        if !current_user.admin
            redirect_to root_path
            flash[:alert] = "You do not have permission to enter that page."
        end
    end

    def update
        if !current_user.admin
            redirect_to root_path
            flash[:alert] = "You do not have permission to enter that page."
        end
        if @league.update(league_params)
            flash[:success] = "Your league has been updated!"
            redirect_to @league
        else
            flash[:error] = "Your league couldn't be updated. Please check the form."
            render :edit
        end
    end

    def show
        @data = []
        @league.current_season.teams.includes(:players).each do |team|
            @data.push(team.standingsData) if team.visibility
        end

        sql_stats = SeasonPlayerStat.all.where(season_id: @league.current_season.id).as_json.each do |s|
            u = User.find(s["user_id"])
            s[:name] = u.user_name
            s[:avatar] = u.get_avatar
        end

        @goal_leader = sql_stats.max_by{ |p| p["games_played"] > 0 ? p["goals"] : 0}
        @assist_leader = sql_stats.max_by{ |p| p["games_played"] > 0 ? p["assists"] : 0}
        @point_leader = sql_stats.max_by{ |p| p["games_played"] > 0 ? p["points"] : 0}
        @pim_leader = sql_stats.max_by{ |p| p["games_played"] > 0 ? p["pim"] : 0}
    end
    
    def players
        @season = @league.current_season
        @sql_stats = SeasonPlayerStat.all.where(season_id: @season.id).as_json.each{|s| s[:name] = User.find(s["user_id"]).user_name}
    end

    def rosters
        @season = @league.current_season
    end

    def destroy
        if !current_user.admin
            redirect_to root_path
            flash[:alert] = "You do not have permission to enter that page."
        end
        @league.destroy
        flash[:success] = "Your league was deleted."
        redirect_to root_path
    end

    def schedule
        @season = @league.current_season
        @games = @season.games
        .order('date ASC')
        .group_by{
            |g| 
                g.date.strftime("%^a %^b %d")
        }
        .to_a
        .map{ 
            |x| 
                [
                    x[0], 
                    x[1].group_by{|g| g.teams}.to_a
                ]
        }
    end

    def history
        @season = @league.current_season
    end

    def leaders
        @season = @league.current_season
        sql_stats = SeasonPlayerStat.all.where(season_id: @season.id).as_json.each do |s|
            u = User.find(s["user_id"])
            s[:name] = u.user_name
            s[:avatar] = u.get_avatar
        end

        @goal_leaders = sql_stats.sort_by { |s| s["goals"] ? 0 - s["goals"] : 0}
        @assist_leaders = sql_stats.sort_by{|s| s["assists"] ? 0 - s["assists"] : 0}
        @point_leaders = sql_stats.sort_by{|s| s["points"] ? 0 - s["points"] : 0}
        @plusminus_leaders = sql_stats.sort_by{|s| s["plus_minus"] ? 0 - s["plus_minus"] : 0}
        @gaa_leaders = sql_stats.sort_by{|s| s["gaa"] ? s["gaa"] : 0}
        @sv_leaders = sql_stats.sort_by{|s| s["sv_per"] ? 0 - s["sv_per"] : 0}
        @gp_leaders = sql_stats.sort_by{|s| s["goalie_games"] ? s["goalie_games"] : 0}
        @so_leaders = sql_stats.sort_by{|s| s["so"] ? 0 - s["so"] : 0}
    end

    def signups
        @season = @league.current_season
        @signups = []
        @season.signups.each do |x|
            @signups.push({
                'name': x.player.user_name,
                'preferred': x.preferred,
                'willing': x.willing.length > 1 ? x.willing.drop(1) : x.willing,
                'mia': x.mia,
                'veteran': x.veteran,
                'part_time': x.part_time,
            })
        end
    end

    def transactions
        @season = @league.current_season
        @pending_trades = @season.trades.where(pending: true).order('created_at ASC')
        @approved_trades = @season.trades.where(approved: true).order('updated_at DESC')
    end

    private

    def league_params
        params.require(:league).permit(:name)
    end

    def set_league
        @league = League.find(params[:id])
    end

    def set_games
        @recent_games = @league.current_season.games
        .where(date: 1.week.ago..1.week.from_now)
        .order('date ASC')
        .group_by{
            |g| 
                g.date.strftime("%^a %^b %d")
        }
        .to_a
        .map{ 
            |x| 
                [
                    x[0], 
                    x[1].group_by{|g| g.teams}.to_a
                ]
        }
    end
end