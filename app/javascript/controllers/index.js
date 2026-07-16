// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import BuyerRoomController from "controllers/buyer_room_controller"
application.register("buyer-room", BuyerRoomController)
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
