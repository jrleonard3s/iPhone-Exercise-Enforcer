//
//  ExerciseEnforcerModel.swift
//  Exercise Enforcer Phone
//
//  Created by Joshua Leonard on 12/11/24.
//

import Foundation

struct ExerciseEnforcerModel {
    private(set) var lastHeartRate: Int = 0
    
    mutating func updateHeartRate(_ heartRate: Int) {
        lastHeartRate = heartRate
    }
}
