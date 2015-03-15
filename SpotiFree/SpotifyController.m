//
//  SpotifyController.m
//  SpotiFree
//
//  Created by Eneas on 21.12.13.
//  Copyright (c) 2013 Eneas. All rights reserved.
//

#import "SpotifyController.h"
#import "Spotify.h"
#import "AppData.h"
#import "AppDelegate.h"

#define SPOTIFY_BUNDLE_IDENTIFIER @"com.spotify.client"

#define IDLE_TIME 0.5
#define TIMER_CHECK_AD [NSTimer scheduledTimerWithTimeInterval:IDLE_TIME target:self selector:@selector(checkForAd) userInfo:nil repeats:YES]
#define TIMER_CHECK_MUSIC [NSTimer scheduledTimerWithTimeInterval:IDLE_TIME target:self selector:@selector(checkForMusic) userInfo:nil repeats:YES]

@interface SpotifyController () {
    NSInteger _currentVolume;
}

@property (strong) SpotifyApplication *spotify;
@property (strong) AppData *appData;
@property (strong) NSTimer *timer;

@property (assign) BOOL shouldRun;

@end

@implementation SpotifyController

#pragma mark -
#pragma mark Initialisation
+ (id)spotifyController {
    return [[self alloc] init];
}

- (id)init
{
    self = [super init];

    if (self) {
        self.spotify = [SBApplication applicationWithBundleIdentifier:SPOTIFY_BUNDLE_IDENTIFIER];
        self.appData = [AppData sharedData];
        
        self.shouldRun = YES;
        [self addObserver:self forKeyPath:@"shouldRun" options:NSKeyValueObservingOptionOld context:nil];
        
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged) name:@"com.spotify.client.PlaybackStateChanged" object:nil];
    }

    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"shouldRun"]) {
        if (self.shouldRun) {
            if (self.timer)
                [self.timer invalidate];
            self.timer = TIMER_CHECK_AD;
        } else {
            if (self.timer) {
                [self.timer invalidate];
            }
        }

        if ([self.delegate respondsToSelector:@selector(activeStateShouldGetUpdated:)]) {
            [self.delegate activeStateShouldGetUpdated:(self.shouldRun ? kSFSpotifyStateActive : kSFSpotifyStateInactive)];
        }
    }
}

- (void)playbackStateChanged {
    if (self.shouldRun && ![self isPlaying]) {
        self.shouldRun = NO;
    } else if ((!self.shouldRun) && [self isPlaying]) {
        self.shouldRun = YES;
    }
}

#pragma mark -
#pragma mark Public Methods
- (void)startService {
    [self playbackStateChanged];
    
    if (self.shouldRun) {
        self.timer = TIMER_CHECK_AD;
    }
}

#pragma mark -
#pragma mark Timer Methods
- (void)checkForAd {
    if ([self isAnAd]) {
        [self.timer invalidate];
        [self mute];
        self.timer = TIMER_CHECK_MUSIC;

		if ([self.delegate respondsToSelector:@selector(activeStateShouldGetUpdated:)]) {
            [self.delegate activeStateShouldGetUpdated:kSFSpotifyStateBlockingAd];
        }
    }
}

- (void)checkForMusic {
    if ([self isAnAd]) {
        return;
    }
    
    [self.timer invalidate];
    [self unmute];

    if (self.shouldRun) {
        self.timer = TIMER_CHECK_AD;
    }
    
    if ([self.delegate respondsToSelector:@selector(activeStateShouldGetUpdated:)]) {
        [self.delegate activeStateShouldGetUpdated:(self.shouldRun ? kSFSpotifyStateActive : kSFSpotifyStateInactive)];
    }
}

#pragma mark -
#pragma mark Player Control Methods
- (void)mute {
    _currentVolume = self.spotify.soundVolume;
    [self.spotify pause];
    [self.spotify setSoundVolume:0];
    [self.spotify play];

	if (self.appData.shouldShowNotifications) {
		NSUserNotification *notification = [[NSUserNotification alloc] init];
		[notification setTitle:@"Spotifree"];
		[notification setInformativeText:[NSString stringWithFormat:@"A Spotify ad was detected! Music will be back in about %ld seconds…", (long)self.spotify.currentTrack.duration]];
		[notification setSoundName:nil];

		[[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
	}
}

- (void)unmute {
    [self.spotify setSoundVolume:_currentVolume];
}

- (BOOL)isAnAd {
    bool isAnAd;
    
    @try {
        isAnAd = [self.spotify.currentTrack.spotifyUrl hasPrefix:@"spotify:ad"];
    }
    @catch (NSException *exception) {
        isAnAd = false;
        NSLog(@"Cannot check if current Spotify track is an ad: %@", exception.reason);
    }
    
    return isAnAd;
}

- (BOOL)isPlaying {
    bool isPlaying;
    
    @try {
        isPlaying = [self isRunning] && self.spotify.playerState == SpotifyEPlSPlaying;
    }
    @catch (NSException *exception) {
        isPlaying = false;
        NSLog(@"Cannot check if Spotify is playing: %@", exception.reason);
    }
    
    return isPlaying;
}

- (BOOL)isRunning {
    bool isRunning;
    
    @try {
        isRunning = self.spotify.isRunning;
    }
    @catch (NSException *exception) {
        isRunning = false;
        NSLog(@"Cannot check if Spotify is running: %@", exception.reason);
    }
    
    return isRunning;
}

- (void)dealloc {
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
    [self removeObserver:self forKeyPath:@"shouldRun"];
}

@end
