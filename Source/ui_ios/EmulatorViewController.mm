#include "PathUtils.h"
#import "EmulatorViewController.h"
#import "GlEsView.h"
#include "../PS2VM.h"
#include "../PS2VM_Preferences.h"
#include "../AppConfig.h"
#include "PreferenceDefs.h"
#include "GSH_OpenGLiOS.h"
#include "../ui_shared/BootablesProcesses.h"
#include "PH_Generic.h"
#include "../../tools/PsfPlayer/Source/SH_OpenAL.h"
#include "../ui_shared/StatsManager.h"

CPS2VM* g_virtualMachine = nullptr;
CGSHandler::NewFrameEvent::Connection g_newFrameConnection;
#ifdef PROFILE
CPS2VM::ProfileFrameDoneSignal::Connection g_profileFrameDoneConnection;
#endif

@interface EmulatorViewController ()

@end

@implementation EmulatorViewController

+(void)registerPreferences
{
	CAppConfig::GetInstance().RegisterPreferenceBoolean(PREFERENCE_UI_SHOWFPS, false);
	CAppConfig::GetInstance().RegisterPreferenceBoolean(PREFERENCE_UI_SHOWVIRTUALPAD, true);
	CAppConfig::GetInstance().RegisterPreferenceBoolean(PREFERENCE_AUDIO_ENABLEOUTPUT, true);
}

-(void)viewDidLoad
{
    self.connectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidConnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        if ([[GCController controllers] count] == 1) {
            [self toggleHardwareController:YES];
        }
    }];
    self.disconnectObserver = [[NSNotificationCenter defaultCenter] addObserverForName:GCControllerDidDisconnectNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        if (![[GCController controllers] count]) {
            [self toggleHardwareController:NO];
        }
    }];
    
    if ([[GCController controllers] count]) {
        [self toggleHardwareController:YES];
    }
    
    self.iCadeReader = [[iCadeReaderView alloc] init];
    [self.view addSubview:self.iCadeReader];
    self.iCadeReader.delegate = self;
    self.iCadeReader.active = YES;
}

-(void)viewDidAppear: (BOOL)animated
{
	assert(g_virtualMachine == nullptr);
	g_virtualMachine = new CPS2VM();
	g_virtualMachine->Initialize();
	g_virtualMachine->CreateGSHandler(CGSH_OpenGLiOS::GetFactoryFunction((CAEAGLLayer*)self.view.layer));

	g_virtualMachine->CreatePadHandler(CPH_Generic::GetFactoryFunction());
	
	if(CAppConfig::GetInstance().GetPreferenceBoolean(PREFERENCE_AUDIO_ENABLEOUTPUT))
	{
		g_virtualMachine->CreateSoundHandler(&CSH_OpenAL::HandlerFactory);
	}
	
	const CGRect screenBounds = [[UIScreen mainScreen] bounds];

	if(CAppConfig::GetInstance().GetPreferenceBoolean(PREFERENCE_UI_SHOWVIRTUALPAD))
	{
		auto padHandler = static_cast<CPH_Generic*>(g_virtualMachine->GetPadHandler());
		self.virtualPadView = [[VirtualPadView alloc] initWithFrame: screenBounds padHandler: padHandler];
		[self.view addSubview: self.virtualPadView];
		[self.view sendSubviewToBack: self.virtualPadView];
	}

	if(CAppConfig::GetInstance().GetPreferenceBoolean(PREFERENCE_UI_SHOWFPS))
	{
		[self setupFpsCounter];
	}
	
	g_virtualMachine->Pause();
	g_virtualMachine->Reset();

	auto bootablePath = boost::filesystem::path([self.bootablePath fileSystemRepresentation]);
	if(IsBootableExecutablePath(bootablePath))
	{
		g_virtualMachine->m_ee->m_os->BootFromFile(bootablePath);
	}
	else
	{
		CAppConfig::GetInstance().SetPreferencePath(PREF_PS2_CDROM0_PATH, bootablePath);
		g_virtualMachine->Reset();
		g_virtualMachine->m_ee->m_os->BootFromCDROM();
	}

	g_virtualMachine->Resume();
}

-(void)viewDidDisappear: (BOOL)animated
{
	[self.fpsCounterTimer invalidate];
	self.fpsCounterTimer = nil;
	g_virtualMachine->Pause();
	g_virtualMachine->Destroy();
	delete g_virtualMachine;
	g_virtualMachine = nullptr;
	g_newFrameConnection.reset();
#ifdef PROFILE
	g_profileFrameDoneConnection.reset();
#endif
}

-(void)toggleHardwareController: (BOOL)useHardware
{
	if(useHardware)
	{
		self.gController = [GCController controllers][0];
		if(self.gController.extendedGamepad)
		{
			[self.gController.extendedGamepad setValueChangedHandler:
				^(GCExtendedGamepad* gamepad, GCControllerElement* element)
				{
					auto padHandler = static_cast<CPH_Generic*>(g_virtualMachine->GetPadHandler());
					if(!padHandler) return;
					if     (element == gamepad.buttonA)       padHandler->SetButtonState(PS2::CControllerInfo::CROSS, gamepad.buttonA.pressed);
					else if(element == gamepad.buttonB)       padHandler->SetButtonState(PS2::CControllerInfo::CIRCLE, gamepad.buttonB.pressed);
					else if(element == gamepad.buttonX)       padHandler->SetButtonState(PS2::CControllerInfo::SQUARE, gamepad.buttonX.pressed);
					else if(element == gamepad.buttonY)       padHandler->SetButtonState(PS2::CControllerInfo::TRIANGLE, gamepad.buttonY.pressed);
					else if(element == gamepad.leftShoulder)  padHandler->SetButtonState(PS2::CControllerInfo::L1, gamepad.leftShoulder.pressed);
					else if(element == gamepad.rightShoulder) padHandler->SetButtonState(PS2::CControllerInfo::R1, gamepad.rightShoulder.pressed);
					else if(element == gamepad.leftTrigger)   padHandler->SetButtonState(PS2::CControllerInfo::L2, gamepad.leftTrigger.pressed);
					else if(element == gamepad.rightTrigger)  padHandler->SetButtonState(PS2::CControllerInfo::R2, gamepad.rightTrigger.pressed);
					else if(element == gamepad.dpad)
					{
						padHandler->SetButtonState(PS2::CControllerInfo::DPAD_UP,    gamepad.dpad.up.pressed);
						padHandler->SetButtonState(PS2::CControllerInfo::DPAD_DOWN,  gamepad.dpad.down.pressed);
						padHandler->SetButtonState(PS2::CControllerInfo::DPAD_LEFT,  gamepad.dpad.left.pressed);
						padHandler->SetButtonState(PS2::CControllerInfo::DPAD_RIGHT, gamepad.dpad.right.pressed);
					}
					else if(element == gamepad.leftThumbstick)
					{
						padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_X, gamepad.leftThumbstick.xAxis.value);
						padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_Y, -gamepad.leftThumbstick.yAxis.value);
					}
					else if(element == gamepad.rightThumbstick)
					{
						padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_RIGHT_X, gamepad.rightThumbstick.xAxis.value);
						padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_RIGHT_Y, -gamepad.rightThumbstick.yAxis.value);
					}
				}
			];
		}
		else if(self.gController.gamepad)
		{
			[self.gController.gamepad setValueChangedHandler:
				^(GCGamepad* gamepad, GCControllerElement* element)
				{
					auto padHandler = static_cast<CPH_Generic*>(g_virtualMachine->GetPadHandler());
					if(!padHandler) return;
					if     (element == gamepad.buttonA)       padHandler->SetButtonState(PS2::CControllerInfo::CROSS, gamepad.buttonA.pressed);
					else if(element == gamepad.buttonB)       padHandler->SetButtonState(PS2::CControllerInfo::CIRCLE, gamepad.buttonB.pressed);
					else if(element == gamepad.buttonX)       padHandler->SetButtonState(PS2::CControllerInfo::SQUARE, gamepad.buttonX.pressed);
					else if(element == gamepad.buttonY)       padHandler->SetButtonState(PS2::CControllerInfo::TRIANGLE, gamepad.buttonY.pressed);
					else if(element == gamepad.leftShoulder)  padHandler->SetButtonState(PS2::CControllerInfo::L1, gamepad.leftShoulder.pressed);
					else if(element == gamepad.rightShoulder) padHandler->SetButtonState(PS2::CControllerInfo::R1, gamepad.rightShoulder.pressed);
					else if(element == gamepad.dpad)
					{
						padHandler->SetButtonState(PS2::CControllerInfo::DPAD_UP,    gamepad.dpad.up.pressed);
						padHandler->SetButtonState(PS2::CControllerInfo::DPAD_DOWN,  gamepad.dpad.down.pressed);
						padHandler->SetButtonState(PS2::CControllerInfo::DPAD_LEFT,  gamepad.dpad.left.pressed);
						padHandler->SetButtonState(PS2::CControllerInfo::DPAD_RIGHT, gamepad.dpad.right.pressed);
						padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_X, gamepad.dpad.xAxis.value);
						padHandler->SetAxisState(PS2::CControllerInfo::ANALOG_LEFT_Y, -gamepad.dpad.yAxis.value);
					}
				}
			];
			//Add controller pause handler here
		}
	}
	else
	{
		self.gController = nil;
	}
}

-(void)setupFpsCounter
{
	auto screenBounds = [[UIScreen mainScreen] bounds];

	self.fpsCounterLabel = [[UILabel alloc] initWithFrame: screenBounds];
	self.fpsCounterLabel.textColor = [UIColor whiteColor];
	[self.view addSubview: self.fpsCounterLabel];

#ifdef PROFILE
	self.profilerStatsLabel = [[UILabel alloc] initWithFrame: screenBounds];
	self.profilerStatsLabel.textColor = [UIColor whiteColor];
	self.profilerStatsLabel.font = [UIFont fontWithName: @"Courier" size: 10.f];
	self.profilerStatsLabel.numberOfLines = 0;
	[self.view addSubview: self.profilerStatsLabel];
#endif
	
	g_newFrameConnection = g_virtualMachine->GetGSHandler()->OnNewFrame.Connect(std::bind(&CStatsManager::OnNewFrame, &CStatsManager::GetInstance(), std::placeholders::_1));
#ifdef PROFILE
	g_profileFrameDoneConnection = g_virtualMachine->ProfileFrameDone.Connect(std::bind(&CStatsManager::OnProfileFrameDone, &CStatsManager::GetInstance(), g_virtualMachine, std::placeholders::_1));
#endif
	self.fpsCounterTimer = [NSTimer scheduledTimerWithTimeInterval: 1 target: self selector: @selector(updateFpsCounter) userInfo: nil repeats: YES];
}

-(void)updateFpsCounter
{
	uint32 drawCallCount = CStatsManager::GetInstance().GetDrawCalls();
	uint32 frames = CStatsManager::GetInstance().GetFrames();
	uint32 dcpf = (frames != 0) ? (drawCallCount / frames) : 0;
	self.fpsCounterLabel.text = [NSString stringWithFormat: @"%d f/s, %d dc/f", frames, dcpf];
	[self.fpsCounterLabel sizeToFit];
#ifdef PROFILE
	self.profilerStatsLabel.text = [NSString stringWithUTF8String: CStatsManager::GetInstance().GetProfilingInfo().c_str()];
#endif
	CStatsManager::GetInstance().ClearStats();
}

-(void)onLoadStateButtonClick
{
	auto statePath = g_virtualMachine->GenerateStatePath(0);
	g_virtualMachine->LoadState(statePath);
	NSLog(@"Loaded state from '%s'.", statePath.string().c_str());
}

-(void)onSaveStateButtonClick
{
	auto statePath = g_virtualMachine->GenerateStatePath(0);
	g_virtualMachine->SaveState(statePath);
	NSLog(@"Saved state to '%s'.", statePath.string().c_str());
}

-(void)onExitButtonClick
{
	[self dismissViewControllerAnimated: YES completion: nil];
}

-(IBAction)onPauseButtonClick: (id)sender
{
	UIAlertController* alert = [UIAlertController alertControllerWithTitle: nil message: nil preferredStyle: UIAlertControllerStyleActionSheet];
	alert.popoverPresentationController.sourceView = self.view;
	alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2, 0, 0);
	
	//Load State
	{
		UIAlertAction* action = [UIAlertAction
								 actionWithTitle: @"Load State"
								 style: UIAlertActionStyleDefault
								 handler: ^(UIAlertAction*) { [self onLoadStateButtonClick]; }
								 ];
		[alert addAction: action];
	}

	//Save State
	{
		UIAlertAction* action = [UIAlertAction
								 actionWithTitle: @"Save State"
								 style: UIAlertActionStyleDefault
								 handler: ^(UIAlertAction*) { [self onSaveStateButtonClick]; }
								 ];
		[alert addAction: action];
	}

	//Resume
	{
		UIAlertAction* action = [UIAlertAction
								 actionWithTitle: @"Resume"
								 style: UIAlertActionStyleCancel
								 handler: nil
								 ];
		[alert addAction: action];
	}
	
	//Exit
	{
		UIAlertAction* action = [UIAlertAction
								 actionWithTitle: @"Exit"
								 style: UIAlertActionStyleDestructive
								 handler: ^(UIAlertAction*) { [self onExitButtonClick]; }
								 ];
		[alert addAction: action];
	}

	[self presentViewController: alert animated: YES completion: nil];
}

-(BOOL)prefersStatusBarHidden
{
	return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskLandscape;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self.connectObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:self.disconnectObserver];
}

@end
