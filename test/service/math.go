package main

import(
	"fmt"
	"github.com/manazhao/my_go_rules/test/calculator"
)


func main() {
	a := 10
	b := 20
	c := calculator.Sum(a, b)
	fmt.Print("sum of %v + %v = %v", a, b, c)
}
