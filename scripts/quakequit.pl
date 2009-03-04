use strict;
use Irssi;
use vars qw($VERSION %IRSSI);
$VERSION = "1.0";
%IRSSI = (
	authors		=> "David O\'Rourke",
	contact		=> "phyber [at] #irssi",
	name		=> "quakequit",
	description	=> "Hide the stupid quit/join on QuakeNet when a user registers with nickserv.",
	licence		=> "GPLv2",
	changed		=> "02/03/2009",
);

# Hash to store our temporary ignores in.
my %quits;

# Return 1 if we should process the tag, otherwise 0.
sub process_tag {
	my ($tag) = @_;
	my $netlist = Irssi::settings_get_str('quakequit_networks');
	foreach my $network (split / /, $netlist) {
		if (lc $tag eq lc $network) {
			return 1;
		}
	}
	return 0;
}

# Remove entries from the quits hash.
sub purge_nick {
	my ($nick) = @_;
	Irssi::print "Purging $nick from the quits list";
	delete $quits{$nick};
	return 0;
}

# Process the 'message join' signal. (/JOIN)
sub message_join {
	my ($server_rec, $channel, $nick, $addr) = @_;
	my $tag = $server_rec->{tag};
	# Return if we don't care about this tag.
	if (process_tag($tag) == 0) {
		return 0;
	}
	#Irssi::print "Processing JOIN $tag: $nick $addr";
	# If the joining nick is in our quit hash, don't show the join.
	if ($quits{$nick} == 1) {
		#delete $quits{$nick};
		Irssi::signal_stop();
		return 0;
	}
}

# Process the 'message quit' signal. (/QUIT)
sub message_quit {
	my ($server_rec, $nick, $addr, $reason) = @_;
	my $tag = $server_rec->{tag};
	# Return if we don't care about this tag.
	if (process_tag($tag) == 0) {
		return 0;
	}
	#Irssi::print "Processing QUIT $tag: $nick $addr $reason";
	# If the quit message is registered, add the person to our quit hash and abort the signal.
	if ($reason eq "Registered") {
		$quits{$nick} = 1;
		Irssi::timeout_add_once(1000, 'purge_nick', $nick);
		Irssi::signal_stop();
		return 0;
	}
}

# Sometimes we have to hide server modes on quakenet too.
sub message_irc_mode {
	my ($server_rec, $channel, $nick, $addr, $mode) = @_;
	my $tag = $server_rec->{tag};
	# Return if we don't care about this tag.
	if (process_tag($tag) == 0) {
		return 0;
	}
	Irssi::print "Processing MIM $tag: $channel $nick $addr $mode";
	my $servermask = Irssi::settings_get_str('quakequit_servermask');
	# break the target nicks away from the modes set on them.
	my ($modes, @targets) = split / /, $mode, 2;
	# If the nick exists in the hash and the mode setter is *.quakenet.org, signal_stop.
	foreach my $target (@targets) {
		if ($quits{$target} == 1) {
			Irssi::signal_stop();
			return 0;
		}
	}
}

#sub nick_mode_changed {
#	my ($channel_rec, $nick_rec, $setby, $mode, $type) = @_;
#	my $tag = $channel_rec->{server}->{tag};
#	# Return if we don't care about this tag
#	if (process_tag($tag) == 0) {
#		return 0;
#	}
#	my $nick = $nick_rec->{nick};
#	my $servermask = Irssi::settings_get_str('quakequit_servermask');
#	Irssi::print "Processing MODE $tag: $nick $setby $mode $type";
#	# If the nick exists in the hash and the mode setter is *.quakenet.org, signal_stop.
#	#if (($quits{$nick} == 1) and (lc $setby eq lc $servermask)) {
#	if ($quits{$nick} == 1) {
#		if ($setby eq $servermask) {
#			print "Setby is matching quakenet.org";
#		}
#		Irssi::signal_stop();
#		return 0;
#	}
#}

## Settings
# quakequit_networks: set the networks that you'd like this script to watch
# quakequit_servermask: the name of the server that's setting the modes on rejoin
Irssi::settings_add_str('quakequit', 'quakequit_networks', 'QuakeNet');
Irssi::settings_add_str('quakequit', 'quakequit_servermask', '*.quakenet.org');
# Signals to grab
Irssi::signal_add_last('message irc mode', 'message_irc_mode');
Irssi::signal_add_last('message join', 'message_join');
Irssi::signal_add_last('message quit', 'message_quit');
#Irssi::signal_add('nick mode changed', 'nick_mode_changed');
