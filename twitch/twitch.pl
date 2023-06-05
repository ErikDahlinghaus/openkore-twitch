# Twitch IRC Bot
# Allows console commands to be issued to the bot with !bot <command>
# 
# Required Config
#  twitch 1
#  twitch_user twitchusername
#  twitch_token oauth:yourtoken
#  twitch_channel yourchannel
# Optional Config
#  twitch_server irc.chat.twitch.tv
#  twitch_port 6667

package twitch;

use strict;
use IO::Socket::INET;

use Plugins;
use Commands;
use Globals qw(%config);
use Log qw(message error debug warning);

Plugins::register('twitch', 'Allows control of Kore with Twitch chat.', \&onUnload);

# # Twitch IRC server details
my ($server, $port, $username, $token, $channel, $socket);

my $hooks = Plugins::addHooks(
   ['start3', \&onLoad, undef],
   ['AI_start', \&iterate, undef]
);

sub onLoad {
   $server   = $config{twitch_server} || 'irc.chat.twitch.tv';
   $port     = $config{twitch_port} || 6667;
   $username = $config{twitch_user};
   $token    = $config{twitch_token};
   $channel  = "#" . $config{twitch_channel};
   
   if( !$config{twitch} ) {
      error "[Twitch] Unloading twitch plugin, twitch key missing in config.txt or plugin disabled\n";
      Commands::run('plugin unload twitch');
      return;
   }

   eval {
      $socket = IO::Socket::INET->new(
         PeerAddr => $server,
         PeerPort => $port,
         Proto    => 'tcp'
      ) or die "Can't create socket: $!";

      # Send authentication and join Twitch chat
      # message $socket "CAP REQ :twitch.tv/membership\r\n";
      print $socket "PASS $token\r\n";
      print $socket "NICK $username\r\n";
      print $socket "JOIN $channel\r\n";
      print $socket "USER $username 0 * :OpenKore\r\n";

      1;
   } or do {
      # Handle socket creation failure
      my $error = $@;
      error "[Twitch] Socket creation failed: $error\n";
      Commands::run('plugin unload twitch');
   };
}

sub onUnload {
   Plugins::delHooks($hooks);
   if( $socket ) {
      close($socket);
   }
}

sub parseIrcMessage {
   my ($message) = @_;

   # Remove leading and trailing whitespaces
   $message =~ s/^\s+|\s+$//g;
   debug $message;

   my ($prefix, $command, $user, @params);
   if ($message =~ /^:([^!\s]+)!([^@\s]+)@([^@\s]+)\s+(\S+)\s+(.*)$/) {
      $prefix = ":$1!$2\@$3";
      $user = $2;
      $command = $4;
      my $params_str = $5;
      @params = split(/\s+/, $params_str);
   }
   elsif ($message =~ /^:([^!\s]+)\s+(\S+)\s+([^:]+)\s*:\s*(.*)$/) {
      $prefix = ":$1";
      $command = $2;
      $user = $3;
      my $params_str = $4;
      @params = split(/\s+/, $params_str);
   }
   elsif ($message =~ /^PING\s+:(.*)$/) {
      $command = 'PING';
      @params = ($1);
   }
   else {
      warning "[Twitch] Unable to parse message: $message\n"
   }

   return ($prefix, $command, $user, @params);
}

my $buffer = '';
my @ircCommands;

sub iterate {
   if (!$socket) {
      return;
   }

   my $select = IO::Select->new();
   $select->add($socket);

   if ( $select && !$select->can_read(0) ) {
      return;
   }

   my $bytes_read = $socket->sysread(my $data, 4096);
   if (!$bytes_read) {
      return;
   }

   $buffer .= $data;
   while ($buffer =~ s/^(.*?\r\n)//) {
      my $message = $1;
      push @ircCommands, $message;
   }

   while(@ircCommands) {
      my $ircCommand = shift @ircCommands;
      my ($prefix, $command, $user, @params) = parseIrcMessage($ircCommand);

      if( $command eq "PING" ) {
         my $pong = "PONG " . join(" ", @params) . "\r\n";
         print $socket $pong;
         next;
      }

      if( $command eq "PRIVMSG" ) {
         shift @params;

         my $firstWord = shift @params;
         if( $firstWord ne ":!bot" ) {
            next;
         }

         my $params_length = scalar @params;
         if( $params_length eq 0 ) {
            my $responseMessage = "PRIVMSG " . $channel . " :@" . $user . " Try running '!bot c Hello World' and check https://openkore.com/wiki/Category:Console_Command for more!\r\n";
            print $socket $responseMessage;
            next;
         }

         my @blockedCommands = (
            'relog', 'rc', 'rc2', 'quit', 'plugin',
            'merge', 'send', 'misc_conf', 'guild',
            'eval', 'dump', 'dumpnow', 'create', 'dead',
            'charselect', 'changeprofile', 'auth',
            'gmb', 'gmbb', 'gmcreate', 'gmdc',
            'gmhide', 'gmkickall', 'gmlb', 'gmlbb',
            'gmlnb', 'gmmapmove', 'gmmute', 'gmnb',
            'gmrecall', 'gmremove', 'gmresetskill',
            'gmresetstate', 'gmsummon', 'gmunmute',
            'gmwarpto'
         );

         my $userCommand = join(' ', @params);
         if( $userCommand =~ /^conf\s(-f\s)?\*?(twitch|alias)/ ) {
            my $responseMessage = "PRIVMSG " . $channel . " :BOT BLOCKED @" . $user . " from running command \"" . $userCommand . "\"\r\n";
            print $socket $responseMessage;
            next;
         }

         my $cmd = lc $params[0];
         my @blocked = grep { lc $_ eq $cmd } @blockedCommands;
         if( scalar @blocked != 0 ) {
            my $responseMessage = "PRIVMSG " . $channel . " :BOT BLOCKED @" . $user . " from running command \"" . $userCommand . "\"\r\n";
            print $socket $responseMessage;
            next;
         }
         
         my $response = Commands::run($userCommand);
         my $responseMessage = "PRIVMSG " . $channel . " :BOT SAYS @" . $user . " ran command \"" . $userCommand . "\"\r\n";
         print $socket $responseMessage;
      }
   }
}

1;
