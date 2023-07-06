// Note: Disney diffuse must be multiply by diffuseAlbedo / PI. This is done outside of this function.
half MyDisneyDiffuse(half NdotV, half NdotL, half LdotH, half perceptualRoughness)
{
    half fd90 = 0.5 + 2 * LdotH * LdotH * perceptualRoughness;
    // Two schlick fresnel term
    half lightScatter   = 1 + (fd90 - 1) * pow((1 - NdotL),5);
    half viewScatter    = 1 + (fd90 - 1) * pow((1 - NdotV),5);

    return lightScatter * viewScatter;
}

half DisneyDiffuseLight(half NdotL, half LdotH, half perceptualRoughness)
{
    half fd90 = 0.5 + 2 * LdotH * LdotH * perceptualRoughness;
    // Two schlick fresnel term
    half lightScatter   = 1 + (fd90 - 1) * pow((1 - NdotL),5);

    return lightScatter;
}

half DisneyDiffuseView(half NdotV,half LdotH, half perceptualRoughness)
{
    half fd90 = 0.5 + 2 * LdotH * LdotH * perceptualRoughness;
    // Two schlick fresnel term
    half viewScatter    = 1 + (fd90 - 1) * pow((1 - NdotV),5);

    return viewScatter;
}