//
//  RootViewController.swift
//  SerialBox
//
//  Created by Matt on 4/7/18.
//  Copyright © 2018 Reilly. All rights reserved.
//

import UIKit
import MapKit
import SnapKit

enum ViewState {
    case loading
    case found
    case error
}

enum Locations {
    case NYC
    case Cancun

    func title() -> String {
        switch self {
            case .Cancun:
                return "Cancun"
            case .NYC:
                return "NYC"
        }
    }

    func address() -> String {
        switch self {
            case .Cancun:
                return "Cancún, Quintana Roo, México"
            case .NYC:
                return "222 Broadway, New York, NY 10038"
        }
    }
}

class RootViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    let headerTitle                = "Location"
    let mapView                    = MKMapView()
    let locationManager            = CLLocationManager()
    var currentLocation: CLLocation?
    var state:           ViewState = .found
    lazy var loading: UIView = {
        let loader = UIActivityIndicatorView()
        loader.startAnimating()
        loader.color = .gray
        let loadingView: UIView = UIView()
        loadingView.backgroundColor = .white
        loadingView.clipsToBounds = true
        loadingView.layer.cornerRadius = 25
        self.view.addSubview(loadingView)
        loadingView.addSubview(loader)
        loadingView.snp.makeConstraints { (make) -> Void in
            make.center.equalTo(self.view)
            make.size.equalTo(50)
        }
        loader.snp.makeConstraints { (make) -> Void in
            make.size.equalTo(50)
            make.center.equalTo(loadingView)
        }
        return loadingView
    }()
    lazy var toolbar: UIToolbar = {
        let wrapper = UIToolbar()
        self.view.addSubview(wrapper)
        wrapper.isTranslucent = true
        wrapper.snp.makeConstraints { (make) -> Void in
            make.leading.trailing.equalTo(self.view)
            make.bottom.equalTo(self.view)
        }
        return wrapper
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(mapView)
        self.title = self.headerTitle
        mapView.frame = self.view.frame
        mapView.showsUserLocation = true
        mapView.delegate = self
        self.toolbar.items = buildToolbar()
        self.determineCurrentLocation()
    }

    func buildToolbar() -> [UIBarButtonItem] {
        let fixed    = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
        let work
                     = UIBarButtonItem(title: "Go to work", style: .plain, target: self, action: #selector(clickedWork(sender:)))
        let vacation = UIBarButtonItem(title: "Go to vacation", style: .plain, target: self, action: #selector(clickedMexico(sender:)))
        return [work, fixed, vacation]
    }

    @objc
    func clickedWork(sender: UIBarButtonItem) {
        navigate(to: Locations.NYC.address())
        updateTitle(Locations.NYC.title())
    }

    @objc
    func clickedMexico(sender: UIBarButtonItem) {
        navigate(to: Locations.Cancun.address())
        updateTitle(Locations.Cancun.title())
    }

    func updateTitle(_ title: String) {
        self.title = title
    }

    func buildDirections(to: CLLocationCoordinate2D) {
        guard let currLoc = self.currentLocation?.coordinate else {
            self.updateState(state: .found)
            print("No location available")
            return
        }
        let request = MKDirectionsRequest()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: currLoc, addressDictionary: nil))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to, addressDictionary: nil))
        request.transportType = .automobile
        let directions = MKDirections(request: request)
        directions.calculate { [unowned self] response, _ in
            guard let unwrappedResponse = response else {
                return
            }
            for route in unwrappedResponse.routes {
                self.mapView.add(route.polyline)
                var rect = route.polyline.boundingMapRect
            }
            self.updateState(state: .found)
        }

    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let userLocation = locations[0] as CLLocation
        self.currentLocation = userLocation
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
        renderer.strokeColor = .cyan
        return renderer
    }

    func updateState(state: ViewState) {
        switch state {
            case .found:
                self.loading.isHidden = true
            case .loading:
                self.loading.isHidden = false
            case .error:
                self.loading.isHidden = false
                self.title = "Error"
        }
    }

    func determineCurrentLocation() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        } else {
            print("No location services")
        }
    }

    func navigate(to location: String) {
        updateState(state: .loading)
        let request = MKLocalSearchRequest()
        request.naturalLanguageQuery = location
        request.region = mapView.region
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let response = response else {
                return
            }
            let span   = MKCoordinateSpanMake(0.05, 0.05)
            let region = MKCoordinateRegionMake(self.parseMapQuery(response: response), span)
            self.mapView.setRegion(region, animated: true)
            self.buildDirections(to: region.center)
        }
    }

    func parseMapQuery(response: MKLocalSearchResponse) -> CLLocationCoordinate2D {
        if !response.mapItems.isEmpty {
            return response.mapItems[0].placemark.coordinate
        } else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
