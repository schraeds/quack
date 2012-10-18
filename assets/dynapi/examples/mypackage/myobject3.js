function MyObject3() {
	this.MyObject2=MyObject2;
	this.MyObject2();
	
	this.value3 = 3;
}
dynapi.setPrototype('MyObject3','MyObject2');
