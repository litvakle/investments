//
//  CurrentPricesFlow.swift
//  InvestmentsApp
//
//  Created by Lev Litvak on 30.09.2022.
//

import Combine
import InvestmentsFrameworks

public class CurrentPricesFlow: ObservableObject {
    var cancellables = Set<AnyCancellable>()
    
    init() {}
    
    public func setupSubscriptions(currentPricesViewModel: CurrentPricesViewModel, transactionsViewModel: TransactionsViewModel, alertViewModel: AlertViewModel) {
        transactionsViewModel.$transactions
            .map { updatedTransactions -> [String] in
                let ticketsInTransactions = Set(updatedTransactions.map { $0.ticket })
                let ticketsWithLoadedPrices = Set(currentPricesViewModel.currentPrices.keys)
                return Array(ticketsInTransactions.subtracting(ticketsWithLoadedPrices))
            }
            .filter { !$0.isEmpty }
            .sink { tickets in
                print(tickets)
                currentPricesViewModel.loadPrices(for: tickets)
            }
            .store(in: &cancellables)
        
        currentPricesViewModel.$error
            .dropFirst()
            .map { $0 != nil }
            .sink { showError in
                alertViewModel.showAlert(title: "Error", message: "Error loading current prices")
            }
            .store(in: &cancellables)
    }
}
