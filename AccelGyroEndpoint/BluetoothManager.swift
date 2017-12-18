//
//  BluetoothManager.swift
//  AccelGyroEndpoint
//
//  Created by Jay Tucker on 11/29/17.
//  Copyright © 2017 Imprivata. All rights reserved.
//

import Foundation
import CoreBluetooth

enum BluetoothConnection: String {
    case disconnected, searching, connected
}

protocol BluetoothManagerDelegate {
    func updateConnection(bluetoothConnection: BluetoothConnection)
    func updateData(data: String, isRequested: Bool)
}

final class BluetoothManager: NSObject {
    
    private let serviceUUID                     = CBUUID(string: "16884184-C1C4-4BD1-A8F1-6ADCB272B18B")
    private let setIntervalCharacteristicUUID   = CBUUID(string: "81426A40-F761-4F45-A58B-D27A780AAEF9")
    private let getMotionDataCharacteristicUUID = CBUUID(string: "0246FAC2-1145-409B-88C4-F43D4E05A8C5")

    private let timeoutInSecs = 5.0
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    private var setIntervalCharacteristic: CBCharacteristic!
    private var getMotionDataCharacteristic: CBCharacteristic!

    private var isPoweredOn = false
    private var scanTimer: Timer!
    
    var delegate: BluetoothManagerDelegate?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate:self, queue:nil)
    }
    
    private func startScanForPeripheral(serviceUuid: CBUUID) {
        log("startScanForPeripheral")

        centralManager.stopScan()
        scanTimer = Timer.scheduledTimer(timeInterval: timeoutInSecs, target: self, selector: #selector(timeout), userInfo: nil, repeats: false)
        centralManager.scanForPeripherals(withServices: [serviceUuid], options: nil)
        
        delegate?.updateConnection(bluetoothConnection: .searching)
    }
    
    // can't be private because called by timer
    @objc func timeout() {
        log("timed out")
        centralManager.stopScan()
        delegate?.updateConnection(bluetoothConnection: .disconnected)
    }
    
    func updateNow() {
        let data = "7.5".data(using: .utf8)!
        peripheral.writeValue(data, for: setIntervalCharacteristic, type: .withResponse)
    }
    
}

extension BluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        var caseString: String!
        switch central.state {
        case .unknown:
            caseString = "unknown"
        case .resetting:
            caseString = "resetting"
        case .unsupported:
            caseString = "unsupported"
        case .unauthorized:
            caseString = "unauthorized"
        case .poweredOff:
            caseString = "poweredOff"
        case .poweredOn:
            caseString = "poweredOn"
        }
        log("centralManagerDidUpdateState \(caseString!)")
        isPoweredOn = centralManager.state == .poweredOn
        if isPoweredOn {
            startScanForPeripheral(serviceUuid: serviceUUID)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        log("centralManager didDiscoverPeripheral")
        scanTimer.invalidate()
        centralManager.stopScan()
        self.peripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("centralManager didConnectPeripheral")
        self.peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
    
}

extension BluetoothManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        let message = "peripheral didDiscoverServices " + (error == nil ? "ok" :  ("error " + error!.localizedDescription))
        log(message)
        guard error == nil else { return }
        for service in peripheral.services! {
            log("service \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        let invalidatedUuids = invalidatedServices.map { $0.uuid }
        let message = "peripheral didModifyServices invalidatedServices: \(invalidatedServices.count) \(invalidatedUuids)"
        log(message)
        if !invalidatedUuids.isEmpty {
            delegate?.updateConnection(bluetoothConnection: .disconnected)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let message = "peripheral didDiscoverCharacteristicsFor service " + (error == nil ? "\(service.uuid.uuidString) ok" :  ("error " + error!.localizedDescription))
        log(message)
        guard error == nil else { return }
        for characteristic in service.characteristics! {
            log("characteristic \(characteristic.uuid.uuidString)")
            if characteristic.uuid == setIntervalCharacteristicUUID {
                self.setIntervalCharacteristic = characteristic
            } else  if characteristic.uuid == getMotionDataCharacteristicUUID {
                self.getMotionDataCharacteristic = characteristic
            }
        }
        delegate?.updateConnection(bluetoothConnection: .connected)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        let message = "peripheral didWriteValueFor characteristic " + (error == nil ? "\(characteristic.uuid.uuidString) ok" :  ("error " + error!.localizedDescription))
        log(message)
        guard error == nil else { return }
        peripheral.readValue(for: getMotionDataCharacteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let message = "peripheral didUpdateValueFor characteristic " + (error == nil ? "\(characteristic.uuid.uuidString) ok" :  ("error " + error!.localizedDescription))
        log(message)
        guard error == nil else { return }
        let response = String(data: characteristic.value!, encoding: String.Encoding.utf8)!
        log(response)
        delegate?.updateData(data: response, isRequested: true)
    }
    
}
