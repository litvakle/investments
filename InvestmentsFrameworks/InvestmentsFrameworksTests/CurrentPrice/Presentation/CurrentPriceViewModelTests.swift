//
//  CurrentPriceViewModelTests.swift
//  InvestmentsFrameworksTests
//
//  Created by Lev Litvak on 28.09.2022.
//

import XCTest
import Combine
import InvestmentsFrameworks

protocol CurrentPriceLoader {
    func loadPrice(for ticket: String)
}

class CurrentPriceViewModel: ObservableObject {
    let loader: () -> AnyPublisher<CurrentPrice, Error>
    var error: String?
    var cancellables = Set<AnyCancellable>()
    
    init(loader: @escaping () -> AnyPublisher<CurrentPrice, Error>) {
        self.loader = loader
    }
    
    func loadPrices(for tickets: [String]) {
        error = nil
        
        tickets.forEach { [weak self] ticket in
            loader()
                .sink { completion in
                    if case .failure = completion {
                        self?.error = "Error loading prices"
                    }
                } receiveValue: { _ in
                    
                }
                .store(in: &cancellables)
        }
    }
}

class CurrentPriceViewModelTests: XCTestCase {
    func test_init_doesNotRequestLoader() {
        let (_, loader) = makeSUT()
        
        XCTAssertTrue(loader.requests.isEmpty)
    }
    
    func test_loadPrices_requestsLoader() {
        let (sut, loader) = makeSUT()
        let tickets0 = ["AAA", "BBB"]
        let tickets1 = ["CCC"]
        
        sut.loadPrices(for: tickets0)
        sut.loadPrices(for: tickets1)
        
        XCTAssertEqual(loader.requests.count, 3)
    }
    
    func test_loadPrices_deliversErrorOnErrorWithAtLeastOneTicket() {
        let (sut, loader) = makeSUT()
        let tickets = ["AAA", "BBB", "CCC", "DDD", "EEE"]
        
        XCTAssertNil(sut.error)
        
        sut.loadPrices(for: tickets)
        loader.completeCurrentPriceLoading(with: CurrentPrice(price: 0), at: 0)
        loader.completeCurrentPriceLoading(with: CurrentPrice(price: 0), at: 1)
        loader.completeCurrentPriceLoadingWithError(at: 2)
        loader.completeCurrentPriceLoading(with: CurrentPrice(price: 0), at: 3)
        loader.completeCurrentPriceLoading(with: CurrentPrice(price: 0), at: 4)
        
        XCTAssertNotNil(sut.error)
    }
    
    func test_loadPrices_doesNotDeliverErrorOnSuccessfulLoadAfterLoadWithError() {
        let (sut, loader) = makeSUT()
        let tickets0 = ["AAA", "BBB"]
        let tickets1 = ["CCC", "DDD"]
        
        sut.loadPrices(for: tickets0)
        loader.completeCurrentPriceLoadingWithError(at: 0)
        loader.completeCurrentPriceLoading(with: CurrentPrice(price: 0), at: 1)
        
        sut.loadPrices(for: tickets1)
        loader.completeCurrentPriceLoading(with: CurrentPrice(price: 0), at: 2)
        loader.completeCurrentPriceLoading(with: CurrentPrice(price: 0), at: 3)
        
        XCTAssertNil(sut.error)
    }
    
    // MARK: - Helpers
    
    private func makeSUT(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (CurrentPriceViewModel, LoaderSpy) {
        let loader = LoaderSpy()
        let sut = CurrentPriceViewModel(loader: loader.loadPublisher)
        
        trackForMemoryLeaks(loader, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        
        return (sut, loader)
    }
    
    private class LoaderSpy {
        var requests = [PassthroughSubject<CurrentPrice, Error>]()
        
        var loadFeedCallCount: Int {
            return requests.count
        }
        
        func loadPublisher() -> AnyPublisher<CurrentPrice, Error> {
            let publisher = PassthroughSubject<CurrentPrice, Error>()
            requests.append(publisher)
            return publisher.eraseToAnyPublisher()
        }
        
        func completeCurrentPriceLoadingWithError(at index: Int = 0) {
            requests[index].send(completion: .failure(anyNSError()))
        }
        
        func completeCurrentPriceLoading(with currentPrice: CurrentPrice, at index: Int = 0) {
            requests[index].send(currentPrice)
            requests[index].send(completion: .finished)
        }
    }
}
