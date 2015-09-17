#!/usr/bin/perl

use strict;
use warnings;

use Getopt::Long;
use File::Slurp;
use LWP::UserAgent;

sub download_fragments {
	my $base_url = shift;
	my $tmp_directory = shift;


	my $ua = LWP::UserAgent->new;
	$ua->timeout(10);

	my $seg = 1;
	my @filenames = ();
	my $filename;

	while (1) {
		my $response = $ua->get("$base_url$seg");
		print "Downloading fragment $seg...\n";
		if ($response->is_success) {
			$filename = $response->filename();
			File::Slurp::write_file("$tmp_directory/$filename", $response->content());
		} else {
			if ($response->code() == 404 && $seg > 1) {
				my $last_seg = $seg - 1;
				my $fragment_base = $filename;
				$fragment_base =~ s/$last_seg$//ig;
				return $fragment_base;
			} else {
				return undef;
			}
		}
		$seg++;
	}
}

sub merge_fragments {
	my $fragment_base = shift;
	my $tmp_directory = shift;

	system("php Scripts/AdobeHDS.php --delete --outdir $tmp_directory --outfile $fragment_base --fragments $tmp_directory/$fragment_base");
	my $exit_code = $? >> 8;

	if ($exit_code == 0) {
		return "$fragment_base.flv";
	} else {
		return undef;
	}
}

sub transcode {
	my $flv_filename = shift;
	my $tmp_directory = shift;
	my $output_file_name = shift;
	my $output_directory = shift;

	system("ffmpeg -i $tmp_directory/$flv_filename -c:a copy -c:v copy '$output_directory/$output_file_name.mp4'");
        my $exit_code = $? >> 8;

        if ($exit_code == 0) {
		unlink("$tmp_directory/$flv_filename");
                return 1;
        } else {
                return undef;
        }
}

my $file = "";
my $file_name_template = "video_%02i";
my $output_directory = "./";
my $tmp_directory = "/tmp/video_download";

GetOptions (	"file=s" => \$file,
		"file_name_template=s" => \$file_name_template,
		"output_directory=s" => \$output_directory,
		"tmp_directory=s" => \$tmp_directory,

) or die("Error in command line arguments\n");

if (! -f $file) {
	die "File '$file' not found";
}
if (! -d $tmp_directory) {
	die "Temporary directory '$tmp_directory' not found";
}
if (! -d $output_directory) {
	die "Output directory '$output_directory' not found";
}

my $stubs = File::Slurp::read_file($file, array_ref => 1);
my $i = 1;
foreach my $stub (@{$stubs}) {
	chomp($stub);
	if (length($stub) > 0) {
		my $fragment_base = download_fragments($stub, $tmp_directory);
		if ($fragment_base) {
			my $merge_filename = merge_fragments($fragment_base, $tmp_directory);
			if ($merge_filename) {
				my $output_filename = sprintf($file_name_template, $i);
				transcode($merge_filename, $tmp_directory, $output_filename, $output_directory);
			} else {

			}
		} else {
			
		}
	}
}
