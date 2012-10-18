function MyObject2() {
	this.MyObject1=MyObject1;
	this.MyObject1();
	
	this.value2 = 2;
}
dynapi.setPrototype('MyObject2','MyObject1');
