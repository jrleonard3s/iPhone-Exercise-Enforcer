//
//  ExerciseEnforcer.swift
//  Exercise Enforcer Phone
//
//  Created by Joshua Leonard on 12/11/24.
//

import Foundation
import MediaPlayer
import Foundation
import HealthKit

class ExerciseEnforcer: ObservableObject {
    var model: ExerciseEnforcerModel = ExerciseEnforcerModel()
    @Published private(set) var currentHeartRate: UInt = 0
    @Published private(set) var currentHeartRateZone: UInt = 0
    
    // Healthkit
    private var healthStore: HKHealthStore
    private var queryAnchor: HKQueryAnchor?
    private var query: HKAnchoredObjectQuery?
    
    // Heart rate values
    let TARGET_ZONE_MAX: UInt
    let TARGET_ZONE_MIN: UInt
    private(set) var TARGET_ZONES : [UInt]
    var lastHeartRateReadTime: Date = Date()
    
    var session = AVAudioSession.sharedInstance()
    
    var paused = false
    
    init(){
        // Default to my max hr
        let user_max_heartrate: UInt = 187
        // For testing
        // var user_max_heartrate: UInt = 140

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        } else {
            fatalError("Health data not available")
        }
        
        // Set heart rate constants
        TARGET_ZONE_MAX = user_max_heartrate
        TARGET_ZONES = [0, UInt(Double(TARGET_ZONE_MAX) * 0.5), UInt(Double(TARGET_ZONE_MAX) * 0.6), UInt(Double(TARGET_ZONE_MAX) * 0.7), UInt(Double(TARGET_ZONE_MAX) * 0.8), UInt(Double(TARGET_ZONE_MAX) * 0.9)]
        TARGET_ZONE_MIN = TARGET_ZONES[2]
        
        self.requestAuthorization { authorised in
            if authorised {
                self.setupQuery()
            }
        }
    }
    
    func incrementHeartRate(){
        currentHeartRate += 1
        interruptMusic(true)
        print(currentHeartRate)
    }
    
    /* -- Health Kit Interactions -- */
    func requestAuthorization(completion: @escaping (Bool) -> Void){
        let heartBeat = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
        
        self.healthStore.requestAuthorization(toShare: [], read: [heartBeat]) { (success, error) in completion(success)
        }
    }
    
    func setupQuery() {
        guard let sampleType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }
        let startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())
        
       let predicate = HKQuery.predicateForSamples(withStart: startDate, end: .distantFuture, options: .strictEndDate)
        
        self.query = HKAnchoredObjectQuery(type: sampleType, predicate: predicate, anchor: queryAnchor, limit: HKObjectQueryNoLimit, resultsHandler: self.updateHandler)
        
        //? why set it twice?
        self.query!.updateHandler = self.updateHandler
            
        healthStore.execute(self.query!)
    }
    
    func updateHandler(query: HKAnchoredObjectQuery, newSamples: [HKSample]?, deleteSamples: [HKDeletedObject]?, newAnchor: HKQueryAnchor?, error: Error?) {
        if let error = error {
            print("Health query error \(error)")
        } else {
            if let newSamples = newSamples as? [HKQuantitySample], !newSamples.isEmpty {
                // Samples are almost always all close together, so just grab the first one
                let newRate: UInt = UInt(newSamples[0].quantity.doubleValue(for: HKUnit(from: "count/min")))
                DispatchQueue.main.async {
                    self.updateHeartRate(newRate)
                }
            }

            self.queryAnchor = newAnchor
        }
    }
    
    /* Heart rate handling*/
    
    func updateHeartRate(_ heartRate: UInt) {
        print("time since last success: \(lastSuccessTimeDate.timeIntervalSinceNow)")
        print("time since last failure: \(lastFailureTimeDate.timeIntervalSinceNow)")
        currentHeartRate = heartRate
        print(currentHeartRate)
        // if data is stale throw reset all the values to now
        if(lastHeartRateReadTime + 20 < Date()){
            print("reset from lack of recent data")
            lastHeartRateReadTime = Date()
            lastSuccessTimeDate = Date()
            lastFailureTimeDate = Date()
            return
        }
        lastHeartRateReadTime = Date()
        if(heartRate > TARGET_ZONE_MIN && heartRate < TARGET_ZONE_MAX){
            print("pass")
            lastSuccessTimeDate = Date()
        }
        else{
            print("fail")
            lastFailureTimeDate = Date()
        }
        updateCurrentHeartRateZone()
        enforce()
    }
    
    func updateCurrentHeartRateZone(){
        currentHeartRateZone = calculateHrZone()
    }
    
    func calculateHrZone() -> UInt{
        if(currentHeartRate > TARGET_ZONE_MAX){
        return 6;
      }
        if(currentHeartRate >= TARGET_ZONES[5]){
        return 5;
      }
      if(currentHeartRate >= TARGET_ZONES[4]){
        return 4;
      }
      if(currentHeartRate >= TARGET_ZONES[3]){
        return 3;
      }
      if(currentHeartRate >= TARGET_ZONES[2]){
        return 2;
      }
      if(currentHeartRate >= TARGET_ZONES[1]){
        return 1;
      }
      return 0;
    }
    
    func enforce(){
        // Has been passing for >= HR_THRESHOLD_BUFFER/3 seconds
        // Making the pass criteria shorter than the fail so the positive feedback happens quickly
        if(self.lastSuccessTimeDate >= self.lastFailureTimeDate +  TimeInterval(HR_THRESHOLD_BUFFER/2))
        {
          rewardUser();
        }
        // Has been failing for >= HR_THRESHOLD_BUFFER seconds
        else if(self.lastFailureTimeDate >= self.lastSuccessTimeDate + TimeInterval(HR_THRESHOLD_BUFFER))
        {
          punishUser();
        }
    }
    
    func rewardUser(){
        print("reward!")
        interruptMusic(false)
    }
    func punishUser(){
        print("punish!")
        interruptMusic(true)
    }
    
    let HR_THRESHOLD_BUFFER: Int = 10
    var lastSuccessTimeDate: Date = Date()
    var lastFailureTimeDate: Date = Date()
    
    /* Media interaction */
    func interruptMusic(_ shouldPause: Bool){
        if(shouldPause){
            try? session.setActive(true)
        }
        else {
            try? session.setActive(false, options: AVAudioSession.SetActiveOptions.notifyOthersOnDeactivation)
        }
    }
}
