package main

import (
	"fmt"

	"net/http"
)

func main() {
	http.HandleFunc("/foo", func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet {
			fmt.Fprintf(w, "Hel")
		}
	})

	http.ListenAndServe("0.0.0.0:8080", nil)
}
