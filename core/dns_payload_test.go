package main

import (
	"reflect"
	"testing"
)

func TestParseDNSPayloadEmpty(t *testing.T) {
	got := parseDNSPayload("")
	if got == nil {
		t.Fatal(`parseDNSPayload("") = nil; want non-nil zero-length slice`)
	}
	if len(got) != 0 {
		t.Fatalf(`parseDNSPayload("") = %#v; want zero-length slice, not garbage [""]`, got)
	}
}

func TestParseDNSPayloadWhitespaceOnly(t *testing.T) {
	got := parseDNSPayload(" , ")
	if len(got) != 0 {
		t.Fatalf(`parseDNSPayload(" , ") = %#v; want zero-length slice`, got)
	}
}

func TestParseDNSPayloadPreservesOrder(t *testing.T) {
	got := parseDNSPayload("9.9.9.9:53,1.1.1.1:53,8.8.8.8:53")
	want := []string{"9.9.9.9:53", "1.1.1.1:53", "8.8.8.8:53"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("parseDNSPayload order = %#v; want %#v (first occurrence order retained)", got, want)
	}
}

func TestParseDNSPayloadRemovesEmptyEntries(t *testing.T) {
	got := parseDNSPayload("1.1.1.1:53,, ,8.8.8.8:53")
	want := []string{"1.1.1.1:53", "8.8.8.8:53"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("parseDNSPayload = %#v; want %#v", got, want)
	}
	for i, address := range got {
		if address == "" {
			t.Fatalf("output element %d is empty; no output element may be empty", i)
		}
	}
}

func TestParseDNSPayloadDeduplicates(t *testing.T) {
	got := parseDNSPayload("1.1.1.1:53,8.8.8.8:53,1.1.1.1:53")
	want := []string{"1.1.1.1:53", "8.8.8.8:53"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("parseDNSPayload dedupe = %#v; want %#v (order preserved)", got, want)
	}
}

func TestParseDNSPayloadIPv6SocketAddress(t *testing.T) {
	got := parseDNSPayload("[2606:4700:4700::1111]:53, [::1]:53")
	want := []string{"[2606:4700:4700::1111]:53", "[::1]:53"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("parseDNSPayload ipv6 = %#v; want %#v (bracketed socket text unchanged)", got, want)
	}
}
