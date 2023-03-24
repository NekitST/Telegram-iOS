import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

public final class ApiFetcher {
    public static let current = ApiFetcher(urlString: "http://worldtimeapi.org/api/timezone/Europe/Moscow")
    
    let urlString: String
    public var timestampFromApi: Int32 = 0

    init(urlString: String) {
        self.urlString = urlString
    }

    public func getTimestampFromApi() -> Signal<Int32, NoError> {
        guard let urlString = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed), let url = URL(string: urlString) else {
            return Signal<Int32, NoError>.complete()
        }
        let signalData: Signal<Int32, NoError> = Signal { subscriber in
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "GET"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let session = URLSession.shared
            let dataTask = session.dataTask(with: urlRequest, completionHandler: { data, _, error in
                if error != nil {
                    subscriber.putCompletion()
                }
                if let data = data {
                    guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
                        subscriber.putCompletion()
                        return
                    }
                    guard let dict = json as? [String: Any] else {
                        subscriber.putCompletion()
                        return
                    }
                    guard let timestamp = dict["unixtime"] as? Int32 else {
                        subscriber.putCompletion()
                        return
                    }
                    subscriber.putNext(timestamp)
                    subscriber.putCompletion()
                }
            })
            dataTask.resume()

            return EmptyDisposable
        }
        return signalData |> take(1)
    }
}

public func fetchHttpResource(url: String) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    if let urlString = url.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed), let url = URL(string: urlString) {
        let signal = MTHttpRequestOperation.data(forHttpUrl: url)!
        return Signal { subscriber in
            subscriber.putNext(.reset)
            let disposable = signal.start(next: { next in
                if let response = next as? MTHttpResponse {
                    let fetchResult: MediaResourceDataFetchResult = .dataPart(resourceOffset: 0, data: response.data, range: 0 ..< Int64(response.data.count), complete: true)
                    subscriber.putNext(fetchResult)
                    subscriber.putCompletion()
                } else {
                    subscriber.putError(.generic)
                }
            }, error: { _ in
                subscriber.putError(.generic)
            }, completed: {
            })
            
            return ActionDisposable {
                disposable?.dispose()
            }
        }
    } else {
        return .never()
    }
}
