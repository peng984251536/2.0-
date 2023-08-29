using UnityEngine;

public class HaltonSequenceGenerator
{
    public Vector2[] GenerateHaltonSequence(int samples, int baseX, int baseY)
    {
        Vector2[] sequence = new Vector2[samples];

        for (int i = 0; i < samples; i++)
        {
            float x = HaltonSequence(i, baseX);
            float y = HaltonSequence(i, baseY);
            sequence[i] = new Vector2(x, y);
        }

        return sequence;
    }

    public Vector2 GenerateHaltonSequence2(int samples, int baseX, int baseY)
    {
        float x = HaltonSequence(samples & 1023, baseX);
        float y = HaltonSequence(samples & 1023, baseY);
        Vector2 sequence = new Vector2(x, y);

        return sequence;
    }

    private float HaltonSequence(int index, int baseValue)
    {
        float result = 0f;
        float fraction = 1f / baseValue;

        while (index > 0)
        {
            result += (index % baseValue) * fraction;
            index /= baseValue;
            fraction /= baseValue;
        }

        return result;
    }
}