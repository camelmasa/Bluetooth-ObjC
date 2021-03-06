#import "PeripheralController.h"
@import CoreBluetooth;

#define CHARACTERISTIC_UUID @"c54e5502-0c99-11e8-ba89-0ed5f89f718b"
#define SERVICE_UUID @"bdb57744-0c99-11e8-ba89-0ed5f89f718b"

@interface PeripheralController() < CBPeripheralManagerDelegate >
@property (strong, nonatomic) CBPeripheralManager       *cpmPeripheralManager;
@property (strong, nonatomic) CBMutableCharacteristic   *cmcCharacteristic;
@property (strong, nonatomic) NSMutableData             *mdtSendValue;
@property (strong, nonatomic) NSString                  *strGotValue;
@property (strong, nonatomic) NSMutableArray            *centralDevices;
@property (nonatomic) BOOL                              isSubscribed;
@property (strong,nonatomic)  PeripheralViewController  *viewController;
@end
@implementation PeripheralController
- (void) initPeripheralController:(id)viewController
{
    self.viewController = viewController;
    // PeripheralManagerの初期化. Delegateにselfを設定し、起動時にBluetoothがOffならアラートを表示する.
    _cpmPeripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil options:@{CBPeripheralManagerOptionShowPowerAlertKey:@YES}];
    _isSubscribed = NO;
    _strGotValue = @"";
}

- (void) close
{
    // Advertisingをストップ.
    [self.cpmPeripheralManager stopAdvertising];
}
- (NSString *) getCentralValue
{
    // Centralの書き込みリクエストで受け取った値を返す.
    return _strGotValue;
}

// Bluetoothの状態が変わったら実行される.
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    // BluetoothがOffならリターン.
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        return;
    }
    // Characteristicの初期化. ここで設定したIDをもとにCentralが検索する.
    // Centralからの読み出し、書き込みを可能にする.
    _cmcCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:CHARACTERISTIC_UUID]
                                                            properties:(CBCharacteristicPropertyNotify|CBCharacteristicPropertyRead|CBCharacteristicPropertyWrite)
                                                                 value:nil
                                                           permissions:(CBAttributePermissionsReadable|CBAttributePermissionsWriteable)];
    
    // Serviceの初期化. ここで設定したIDをもとにCentralがServiceを検索する.
    CBMutableService *cmsService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:SERVICE_UUID]
                                                                  primary:YES];
    
    // ServiceのCharacteristicを設定する.
    cmsService.characteristics = @[_cmcCharacteristic];
    
    // PeripheralManagerにServiceを追加する.
    [_cpmPeripheralManager addService:cmsService];
    
        // Advertisingの開始.Centralから探索可能にする.
    [_cpmPeripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:SERVICE_UUID]] }];
    
    // set state text
    [_viewController setStateLabelText:@"Advertising started"];
}

/**
 Peripheralで設定した値を更新したら、Centralに通知がいくようにする(Centralからのリクエストで実行).
 Invoked when a remote central device subscribes to a characteristic’s value.
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"call didSubscribeToCharacteristic");
    [_centralDevices addObject:central];
    _isSubscribed = YES;
}

- (BOOL) updatePeripheralValue:(int) intSendData
{
    if(_isSubscribed)
    {
        // Centralからの読み出しリクエストのための値を更新する.
        _mdtSendValue = (NSMutableData *)[[NSString stringWithFormat:@"%d", intSendData] dataUsingEncoding:NSUTF8StringEncoding];
        if([_cpmPeripheralManager updateValue:_mdtSendValue forCharacteristic:_cmcCharacteristic onSubscribedCentrals:nil])
        {
            return YES;
        }
    }
    return NO;
}

/**
 Invoked when you publish a service,
 and any of its associated characteristics and characteristic descriptors,
 to the local Generic Attribute Profile (GATT) database.
 */
- (void)peripheralManager:(CBPeripheralManager *)peripheral
            didAddService:(CBService *)service
                    error:(NSError *)error{
    NSLog(@"call didAddService");
    if(error == nil){
        // set state text
        [_viewController setStateLabelText:@"add Service"];

    }else{
        
    }
}

// Centralから書き込みリクエストを受けたら実行.
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    for (CBATTRequest *rqs in requests) {
        if ([_cmcCharacteristic isEqual:rqs.characteristic])
        {
            _strGotValue = [[NSString alloc] initWithData:rqs.value encoding:NSUTF8StringEncoding];
            
            [_cpmPeripheralManager respondToRequest:rqs
                                         withResult:CBATTErrorSuccess];
        }
    }
}

-(NSMutableArray*) getCentralDevices{
    return _centralDevices;
}

@end
