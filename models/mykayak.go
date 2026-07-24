package models

import "time"

type Outcome int

const (
	finalA Outcome = iota
	barelyFinalA
	finalB
	barelyFinalB
	finalC
	barelyFinalC
	semiFinal
	barelySemiFinal
)

type Division int

const (
	AllieviA Division = iota
	AllieviB
	CadettiA
	CadettiB
	RagazziPrimo
	Ragazzi
	Junior
	Under23
	Senior
	MasterA
	MasterB
	MasterC
	MasterD
	MasterE
	MasterG
	MasterH
)

type Category int

const (
	Male Category = iota
	Female
	Mixed
)

type Level int

const ( // really ugly and inconsistent
	HeatLevel Level = iota
	SemiFinalLevel
	FinalLevel
)

type Team struct {
	id               string
	name             string
	logo             string
	performanceCount uint32
}

type Athlete struct {
	id      uint32
	name    string
	surname string
	dob     time.Time
}

type Performance struct {
	id        uint32
	heatId    uint32
	teamId    string
	lane      uint8 // ora sicuro fanno le gare da 300 atleti
	placement uint8 // se qualche cristiano osa arrivare 256esimo verrá menato dal sottoscritto.
	timeMs    uint32
	status    string
	outcome   Outcome
	athletes  []Athlete
}

type Heat struct {
	performances []Performance
	index        uint8
	raceId       uint32
	startTime    time.Time
	isResult     bool
}

type Race struct {
	heats     []Heat
	code      string // fetched
	meetId    string
	distance  uint16 // istg se includono le ultramaratone vado personalmente in Viale Tiziano 70 a Roma ad assicurarmi che non superino i 65535 metri
	division  Division
	category  Category
	boat      string // TODO: replace with enum ?
	level     Level
	startTime time.Time
}

type Meet struct {
	races          []Race
	code           string // fetched
	name           string
	location       string
	date           time.Time
	isChampionship bool
}
