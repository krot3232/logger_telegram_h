-module(logger_telegram_h).

-behaviour(logger_handler).

%% logger callbacks
-export([
    log/2,
    adding_handler/1,
    removing_handler/1,
    changing_config/3,
    filter_config/1
]).
-export([
    rate_limit/2
]).
%%telegram limit send 30 messages in 1 sec
-define(RATE_TIME, 1000 div 30).

%%% Handler being added
-doc false.
adding_handler(
    #{
        id := _Id,
        config := #{telegram_send_param := #{chat_id := ChatId}, telegram_pool_options := _TPool} =
            _Conf
    } = Config
) when is_binary(ChatId) ->
    Me = self(),
    {Pid, Ref} = spawn_opt(
        fun() -> init(Me, Config) end,
        [link, monitor, {message_queue_data, off_heap}]
    ),
    receive
        {'DOWN', Ref, process, Pid, Reason} ->
            {error, Reason};
        {Pid, started} ->
            erlang:demonitor(Ref),
            {ok, Config#{telegram_sender_pid => Pid}}
    end;
adding_handler(_) ->
    {error, param}.

%%%-----------------------------------------------------------------
%%% Handler being removed
-doc false.
removing_handler(#{telegram_sender_pid := Pid} = _Config) ->
    Ref = erlang:monitor(process, Pid),
    unlink(Pid),
    Pid ! stop,
    receive
        {'DOWN', Ref, process, Pid, _} ->
            ok
    end,
    ok.

%%%-----------------------------------------------------------------
%%% Updating handler config
-doc false.
changing_config(_SetOrUpdate, #{telegram_sender_pid := Pid} = _OldConfig, NewConfig) ->
    Pid ! {config, NewConfig},
    {ok, NewConfig#{telegram_sender_pid => Pid}}.

%%%-----------------------------------------------------------------
%%% Remove internal fields from configuration
-doc false.
filter_config(Config) ->
    Config.

%%%-----------------------------------------------------------------
%%% Log a string or report
-doc false.
log(LogEvent, #{telegram_sender_pid := Pid} = _Config) ->
    Pid ! {log, LogEvent},
    ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%
init(Starter, #{id := Id, config := #{telegram_pool_options := TPool} = _Conf} = Config) ->
    ok =
        case application_controller:is_running(telegram_bot_api) of
            true ->
                ok;
            _ ->
                {ok, _} = application:ensure_all_started(telegram_bot_api),
                ok
        end,
    PoolName = maps:get(name, TPool, Id),
    {ok, _Pid} =
        try
            telegram_bot_api_sup:start_pool(TPool#{
                name => PoolName,
                workers => maps:get(workers, TPool, 1)
            })
        of
            {ok, Pid1} -> {ok, Pid1};
            {error, {already_started, Pid1}} -> {ok, Pid1}
        catch
            E:M -> {error, {E, M}}
        end,
    Starter ! {self(), started},
    loop(Config#{telegram_pool => PoolName}).
loop(#{telegram_pool := PoolName} = Config) ->
    receive
        {config, NewConfig} ->
            NewConfig1 = NewConfig#{telegram_pool => PoolName},
            loop(NewConfig1);
        stop ->
            ok = telegram_bot_api_sup:stop_pool(PoolName);
        {log, #{msg := _, meta := #{time := _}} = LogEvent} ->
            ConfigNew = do_log(Config, LogEvent),
            loop(ConfigNew);
        _Msg ->
            loop(Config)
    end.

do_log(
    #{id := Id, config := Conf, formatter := {FMod, FConf}, telegram_pool := Pool} = Config,
    #{level := Level, meta := Meta} = LogEvent
) ->
    Param = maps:get(send_param, Meta, maps:get(telegram_send_param, Conf, undef)),
    Message = unicode:characters_to_binary(FMod:format(LogEvent, FConf)),
    Param1 = Param#{text => Message},
    Async = false,
    Result = telegram_bot_api:sendMessage(Pool, Param1, Async),
    Ret =
        case Result of
            {ok, 200, #{ok := true, result := _}} ->
                ok;
            Msg ->
                Fun = maps:get(fun_error_send, Conf, fun logger:log/3),
                Fun(Level, Message, #{
                    domain => [telegram_send_error],
                    telegram_error_msg => Msg,
                    telegram_handler_id => Id
                }),
                case Msg of
                    {ok, 429, #{parameters := #{retry_after := Rate}}} -> {rate, Rate};
                    _ -> error
                end
        end,
    Flimit = maps:get(fun_rate_limit, Conf, fun ?MODULE:rate_limit/2),
    Flimit(Ret, Config).

rate_limit({rate, Rate}, Config) ->
    timer:sleep(Rate * 1000),
    Config;
rate_limit(_R, Config) ->
    Now = erlang:monotonic_time(millisecond),
    OldTime = maps:get(rate_time, Config, -1),
    Elapsed = Now - OldTime,
    case Elapsed of
        E when E < 0 -> ok;
        E when E < ?RATE_TIME ->
            timer:sleep(?RATE_TIME - E);
        _ ->
            ok
    end,
    Config#{rate_time => Now}.
