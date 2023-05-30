# openkore-twitch
This plugin adds support to [OpenKore](https://github.com/OpenKore/openkore) allowing console commands to be issued via Twitch chat.
This offers a "Twitch Plays OpenKore" experience!
There is a list of blacklisted commands in [twitch/twitch.pl](./twitch/twitch.pl) that you may modify to your needs.

## Installation
1. Copy `twitch` folder to `openkore/plugins`.
1. Load the plugin by adding `twitch` to `loadPlugins_list` in `openkore/control/sys.txt`
1. Add your configuration to `openkore/control/config.txt`

```
twitch 1 # enable/disable
twitch_user gnubeardo # your twitch username
twitch_token oauth:vvad7xqmh48wawkty2s3m060yxyxkff # oauth token with oauth:
twitch_channel gnubeardo # your twitch channel with no \#
```

## Usage
See [USAGE.md](./USAGE.md)