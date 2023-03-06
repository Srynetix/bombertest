# Role:
#   A command-line parser implementation (inheriting SxCmdLintParser).
#
#   It is used to parse specific command-line flags, to:
#   - start a server,
#   - start a client,
#   - start a single-player game
#   - enable websockets (instead of ENet)
#   - set a specific map name
#   - set a specific username
#
#   To do so, it simply uses the GameData class to store values.

extends SxCmdLineParser

func _handle_args(args: Args) -> void:
    if args.options.has("server"):
        var server_port := int(args.options.get("server-port", 12341))
        var server_max_players := int(args.options.get("server-max-players", 4))
        GameData.autostart_server = true
        GameData.autostart_server_port = server_port
        GameData.game_max_players = server_max_players

    elif args.options.has("client"):
        var client_server_ip := str(args.options.get("client-server-ip", "127.0.0.1:12341"))
        GameData.autostart_client = true
        GameData.autostart_client_server_ip = client_server_ip

    elif args.options.has("solo"):
        GameData.autostart_solo = true
        GameData.set_game_mode(Enums.GameMode.SOLO)
        GameData.set_map_name("random")

    if args.options.has("websockets"):
        GameData.use_websockets = true

    if args.options.has("map-name"):
        GameData.set_map_name(args.options["map-name"])

    if args.options.has("username"):
        GameData.player_username = args.options["username"]