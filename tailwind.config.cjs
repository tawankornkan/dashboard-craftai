const defaultTheme = require('tailwindcss/defaultTheme.js');

/** @type {import("tailwindcss").Config} */
const config = {
	theme: {
		extend: {
			fontFamily: {
				sans: ['Anuphan', ...defaultTheme.fontFamily.sans]
			}
		}
	}
};

module.exports = config;
