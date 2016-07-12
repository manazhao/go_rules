package calculator

import "testing"

func TestSum(t *testing.T) {
	a := 1
	b := 2
	c := Sum(a, b)
	if a+b != 3 {
		t.Error("Expected 3, got ", c)
	}
}
