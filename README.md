# Telegram Logger handler
<img src="https://raw.githubusercontent.com/krot3232/logos/main/logger_telegram_h.png" width="200">

logger_telegram_h is a custom log handler for the [Erlang/OTP Logger](https://www.erlang.org/docs/26/man/logger.html) that forwards log messages to a Telegram chat via the Telegram Bot API.

It allows you to receive errors, warnings, and other important system events in real time directly in Telegram.

[![Erlang](https://img.shields.io/badge/Erlang%2FOTP-27+-deeppink?style=flat-square&logo=erlang&logoColor=ffffff)](https://www.erlang.org)
[![Hex Version](https://img.shields.io/hexpm/v/logger_telegram_h.svg?style=flat-square)](https://hex.pm/packages/logger_telegram_h)

---
## 📥 Installation
 The package can be installed by adding `logger_telegram_h` to your list of dependencies
in
`rebar.config`:
```erlang
{deps, [logger_telegram_h]}.
```
## ⚙️ Configuration

Add the handler to your logger configuration:

```erlang
Config=#{
    level => all,
    config => #{
      fun_error_send=>fun logger:log/3,%%  Fun(Level, Message, #{domain => [telegram_send_error],telegram_error_msg => Msg,telegram_handler_id => Id })
      telegram_send_param=>#{
                chat_id=><<"@mychat">>
                 %,protect_content=>true
                 %,parse_mode => <<"HTML">>
                 %,message_thread_id
                 %,message_effect_id ..
                %% see req param -> https://hexdocs.pm/telegram_bot_api/telegram_bot_api.html#sendMessage/2
      },
      telegram_pool_options=>#{
            %% see https://hexdocs.pm/telegram_bot_api/telegram_bot_api_sup.html#start_pool/1
            token=><<"1234256789:AAEAAAaAAaVgAAAASSSDDDFFk">> %% Use this token to access the HTTP API, get token @BotFather
      }
    },
     filters => [
      {level, {fun logger_filters:level/2, {stop, neq, error}}},
      {skip_progress_info, {fun logger_filters:progress/2, stop}},
      {ignore_telegram_error_log, {fun logger_filters:domain/2, {stop, sub, [telegram_send_error]}}}
     ],
     formatter =>
            {logger_formatter,#{ 
              single_line => true,
              legacy_header => false,
              chars_limit => 4096,
              max_size => 4096,
              depth => unlimited,
              time_offset => "Z",
              time_designator => $\s,
              template => [time," [",level,"] ",mfa,":",line," ",pid," ",domain," ",msg]
            }
          }
  },
  %%add handler
  ok = logger:add_handler(telegram_handler_1, logger_telegram_h, Config).
```
Remove the handler to your logger:
```erlang
  ok=logger:remove_handler(telegram_handler_1).
```
Set config logger:
```erlang
  ok=logger:set_handler_config(telegram_handler_1, ConfigNew).
```
Update config logger:
```erlang
 ok=logger:update_handler_config(telegram_handler_1,formatter,NewFormater).
```



## 🚀 Macros Log
```erlang
-include_lib("kernel/include/logger.hrl").
?LOG_EMERGENCY("example log ~p", [123]).
?LOG_ALERT("example log ~p", [123]).
?LOG_CRITICAL("example log ~p", [123]).
?LOG_ERROR("example log ~p", [123]).
?LOG_WARNING("example log ~p", [123]).
?LOG_NOTICE("example log ~p", [123]).
?LOG_INFO("example log ~p", [123]).
?LOG_DEBUG("example log ~p", [123]).
```

## 🧪 Example 
Example `config/sys.config`:
```erlang
[
{kernel, [
	{logger_level, all},
	{logger, [
	{handler, default, logger_std_h,
	#{
		level => info,
		filters => [
			{skip_progress_info, {fun logger_filters:progress/2, stop}}
		]
	}},               
	{handler, telegram_handler_1, logger_telegram_h,
	#{
	level => all,
	config => #{
		fun_error_send=>fun logger:log/3,
		fun_rate_limit=>fun logger_telegram_h:rate_limit/2,
		telegram_send_param=>#{
			chat_id=><<"@mychat">>
		},
		telegram_pool_options=>#{
			token=><<"1111111111:tokenxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx">>
		}
		},
		filters => [
			{level, {fun logger_filters:level/2, {stop, neq, error}}},
			{skip_progress_info, {fun logger_filters:progress/2, stop}},
			{ignore_telegram_error_log, {fun logger_filters:domain/2, {stop, sub, [telegram_send_error]}}}
		],
		formatter =>
			{logger_formatter,#{ 
				single_line => true,
				legacy_header => false,
				chars_limit => 4096,
				max_size => 4096,
				depth => unlimited,
				time_offset => "Z",
				time_designator => $\s,
				template => [time," [",level,"] ",mfa,":",line," ",pid," ",domain," ",msg]
			}
			}

		}
	},
{handler, handler_telegram_send_error, logger_std_h,
	#{
		level => debug,
		config => #{
		    file =>"/var/log/telegram_send_error.log"
		},
		filters => [
			{level, {fun logger_filters:level/2, {stop, neq, error}}},
			{skip_progress_info, {fun logger_filters:progress/2, stop}},
			{ignore_telegram_error_log, {fun logger_filters:domain/2, {stop, not_equal, [telegram_send_error]}}}
		],
		formatter => {
			logger_formatter, #{
			single_line => true,time_offset => "Z",time_designator => $\s,
			template => [time,":",telegram_handler_id,":",telegram_error_msg," send:",msg,"\n"]}}
	}
}
]}
]}
].
```

## 📌 Other
* [Erlang library for developing Telegram Bots](https://hex.pm/packages/telegram_bot_api)

