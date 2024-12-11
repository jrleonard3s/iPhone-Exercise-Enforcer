//
//  MainView.swift
//  Exercise Enforcer Phone
//
//  Created by Joshua Leonard on 12/10/24.
//

import SwiftUI

struct MainView: View {
    @ObservedObject var viewModel: ExerciseEnforcer
    var body: some View {
        VStack {
            heartRateView
            Button("Increment"){
                viewModel.incrementHeartRate()
            }
        }
        .padding()
    }
    
    var heartRateView: some View{
        Text(String(viewModel.heartRate))
            .font(.largeTitle)
            .padding()
    }
}







#Preview {
    MainView(viewModel: ExerciseEnforcer())
}
