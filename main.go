package main

import (
	"fmt"
	"log"
	"net/http"

	"github.com/DataDog/datadog-go/statsd"
)

var ddc *statsd.Client

// Answer health checks
func healthHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprint(w, "OK\n")
	routeCounter("health")
}

// answer root requests
func rootHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprint(w, "Hello, World!\n")
	routeCounter("root")
}

// send some metrics
func routeCounter(route string) {
	log.Printf("Counting %s", route)
	if ddc == nil {
		log.Print("Initializing datadog client")
		c, err := statsd.New("127.0.0.1:8125")
		if err != nil {
			log.Fatal(err)
		}
		c.Namespace = "ddleak."
		ddc = c
	}
	routeTag := "routein:" + route
	err := ddc.Count("request", 1, []string{routeTag}, 1.0)
	if err != nil {
		log.Printf("root error: %v", err)
	}
}

func main() {
	http.HandleFunc("/health", healthHandler)
	http.HandleFunc("/", rootHandler)
	log.Printf("Listening")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
