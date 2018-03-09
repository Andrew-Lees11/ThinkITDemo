import Foundation
import Kitura
import LoggerAPI
import Configuration
import CloudEnvironment
import KituraContracts
import Health
import Dispatch
import KituraStencil

public let projectPath = ConfigurationManager.BasePath.project.path
public let health = Health()

public class App {
    let router = Router()
    let cloudEnv = CloudEnv()
    private let workerQueue = DispatchQueue(label: "worker")
    private var score = 0
    private var donators: [String: Any] = [:]

    public init() throws {
        // Run the metrics initializer
        initializeMetrics(router: router)
    }

    func postInit() throws {
        // Endpoints
        initializeHealthRoutes(app: self)
        router.add(templateEngine: StencilTemplateEngine())
        router.get("/", middleware: StaticFileServer())
        router.get("/scores") { request, response, next in
            let context: [String: Any] =
                ["donations": self.score, "donators": [self.donators]]
            print("scores context: \(context)")
            try response.render("scores.stencil", context: context)
            next()
        }
        router.post("/input", middleware: BodyParser())
        router.post("/input") { request, response, next in
            print("entered post")
            print("request body: \(String(describing: request.body))")
            guard let parsedBody = request.body?.asJSON else {
                print("failed body parse")
                next()
                return
            }
            print("parsedbody: \(parsedBody)")
            guard let user = parsedBody["user"] as? String,
                let stringDonation = parsedBody["donation"] as? String,
                let value = Int(stringDonation) else {
                    print("Failed assignment guard let")
                    return
            }
            print("value: \(value)")
            print("donator: \(user)")
            self.score += value
            self.donators[user] = ((self.donators[user] as? Int) ?? 0) + value
            response.status(.OK)
            print("total score: \(self.score)")
            print("all donators: \(self.donators)")
            next()
        }
    }

    public func run() throws {
        try postInit()
        Kitura.addHTTPServer(onPort: cloudEnv.port, with: router)
        Kitura.run()
    }

}
